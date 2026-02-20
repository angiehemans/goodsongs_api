# User Mentions (@tagging) Feature Plan

## Overview

Allow users to tag other users in comments and reviews using `@username` syntax. Tagged users receive notifications and the mentions become clickable links to their profiles in the serialized response.

---

## Database Design

### 1. Mentions Table (Polymorphic)

**Create:** `db/migrate/YYYYMMDDHHMMSS_create_mentions.rb`

```ruby
class CreateMentions < ActiveRecord::Migration[8.0]
  def change
    create_table :mentions do |t|
      t.references :user, null: false, foreign_key: true  # The user being mentioned
      t.references :mentioner, null: false, foreign_key: { to_table: :users }  # Who made the mention
      t.references :mentionable, polymorphic: true, null: false  # The content (Review, ReviewComment, etc.)
      t.timestamps
    end

    add_index :mentions, [:mentionable_type, :mentionable_id, :user_id], unique: true, name: 'index_mentions_uniqueness'
  end
end
```

---

## Files to Create

### 2. Mention Model

**Create:** `app/models/mention.rb`

```ruby
class Mention < ApplicationRecord
  belongs_to :user  # The mentioned user
  belongs_to :mentioner, class_name: 'User'
  belongs_to :mentionable, polymorphic: true

  validates :user_id, uniqueness: {
    scope: [:mentionable_type, :mentionable_id],
    message: 'has already been mentioned in this content'
  }

  # Don't allow self-mentions
  validate :cannot_mention_self

  after_create_commit :send_notification

  private

  def cannot_mention_self
    errors.add(:user, "can't mention yourself") if user_id == mentioner_id
  end

  def send_notification
    Notification.notify_mention(
      mentioned_user: user,
      mentioner: mentioner,
      mentionable: mentionable
    )
  end
end
```

---

### 3. MentionService

**Create:** `app/services/mention_service.rb`

```ruby
class MentionService
  MENTION_REGEX = /@([a-zA-Z0-9_]+)/
  MAX_MENTIONS = 10

  class Error < StandardError; end
  class InvalidUserError < Error; end
  class TooManyMentionsError < Error; end

  def initialize(content, mentioner:, mentionable: nil)
    @content = content
    @mentioner = mentioner
    @mentionable = mentionable
  end

  # Validate mentions before saving (call from controller)
  # Returns { valid: true/false, error: "message", users: [...] }
  def validate
    return { valid: true, users: [] } if @content.blank?

    usernames = extract_usernames
    return { valid: true, users: [] } if usernames.empty?

    # Check mention limit
    if usernames.length > MAX_MENTIONS
      return {
        valid: false,
        error: "You can only mention up to #{MAX_MENTIONS} users per post"
      }
    end

    # Find valid users (exclude self, disabled accounts)
    users = User.where('LOWER(username) IN (?)', usernames)
                .where.not(id: @mentioner.id)
                .where(disabled: false)

    found_usernames = users.map { |u| u.username.downcase }

    # Check for non-self invalid usernames
    invalid = usernames.reject { |u| found_usernames.include?(u) || u == @mentioner.username&.downcase }

    if invalid.any?
      return {
        valid: false,
        error: "Looks like you tagged a user that doesn't exist: @#{invalid.first}"
      }
    end

    { valid: true, users: users }
  end

  # Extract usernames and create mention records (call after save)
  def process_mentions
    return [] if @content.blank? || @mentionable.nil?

    usernames = extract_usernames
    return [] if usernames.empty?

    # Find valid users (exclude self, disabled accounts)
    users = User.where('LOWER(username) IN (?)', usernames)
                .where.not(id: @mentioner.id)
                .where(disabled: false)

    # Create mentions (skip duplicates)
    created_mentions = []
    users.each do |user|
      mention = Mention.find_or_create_by(
        user: user,
        mentioner: @mentioner,
        mentionable: @mentionable
      )
      created_mentions << mention if mention.persisted?
    end

    created_mentions
  end

  # Remove mentions that are no longer in the content (for edits)
  def sync_mentions
    return if @mentionable.nil?

    current_usernames = extract_usernames

    # Get existing mentions
    existing_mentions = @mentionable.mentions.includes(:user)

    # Remove mentions for users no longer in content
    existing_mentions.each do |mention|
      unless current_usernames.include?(mention.user.username.downcase)
        mention.destroy
      end
    end

    # Add new mentions
    process_mentions
  end

  # Format content with mention links for API response
  # Format: [@username](user:id) - easily parsed by both web and mobile
  def self.format_content(content, mentions)
    return content if content.blank? || mentions.empty?

    formatted = content.dup
    mentions.each do |mention|
      formatted.gsub!(
        /@#{Regexp.escape(mention.user.username)}/i,
        "[@#{mention.user.username}](user:#{mention.user.id})"
      )
    end
    formatted
  end

  private

  def extract_usernames
    @content.scan(MENTION_REGEX).flatten.map(&:downcase).uniq
  end
end
```

---

## Files to Modify

### 4. Review Model

**Modify:** `app/models/review.rb`

Add association:
```ruby
has_many :mentions, as: :mentionable, dependent: :destroy
```

Add callback:
```ruby
after_save :process_mentions, if: :saved_change_to_review_text?

private

def process_mentions
  MentionService.new(review_text, mentioner: user, mentionable: self).sync_mentions
end
```

---

### 4b. ReviewsController Updates

**Modify:** `app/controllers/reviews_controller.rb`

Add mention validation in create/update:
```ruby
def create
  # Validate mentions before creating
  mention_service = MentionService.new(review_params[:review_text], mentioner: current_user)
  validation = mention_service.validate
  unless validation[:valid]
    return json_response({ error: validation[:error] }, :unprocessable_entity)
  end

  # ... existing create logic
end

def update
  # Validate mentions before updating
  if review_params[:review_text].present?
    mention_service = MentionService.new(review_params[:review_text], mentioner: current_user)
    validation = mention_service.validate
    unless validation[:valid]
      return json_response({ error: validation[:error] }, :unprocessable_entity)
    end
  end

  # ... existing update logic
end
```

---

### 5. ReviewComment Model

**Modify:** `app/models/review_comment.rb`

Add association:
```ruby
has_many :mentions, as: :mentionable, dependent: :destroy
```

Add callback:
```ruby
after_save :process_mentions, if: :saved_change_to_body?

private

def process_mentions
  MentionService.new(body, mentioner: user, mentionable: self).sync_mentions
end
```

---

### 5b. ReviewCommentsController Updates

**Modify:** `app/controllers/review_comments_controller.rb`

Add mention validation in create/update:
```ruby
def create
  # Validate mentions before creating
  mention_service = MentionService.new(comment_params[:body], mentioner: current_user)
  validation = mention_service.validate
  unless validation[:valid]
    return json_response({ error: validation[:error] }, :unprocessable_entity)
  end

  @comment = @review.review_comments.build(comment_params.merge(user: current_user))
  # ... rest of create logic
end

def update
  # Validate mentions before updating
  mention_service = MentionService.new(comment_params[:body], mentioner: current_user)
  validation = mention_service.validate
  unless validation[:valid]
    return json_response({ error: validation[:error] }, :unprocessable_entity)
  end

  # ... existing update logic
end
```

---

### 6. User Model

**Modify:** `app/models/user.rb`

Add associations:
```ruby
# Mentions (where this user was mentioned)
has_many :mentions, dependent: :destroy
has_many :mentioning_content, through: :mentions, source: :mentionable

# Mentions made by this user
has_many :made_mentions, class_name: 'Mention', foreign_key: :mentioner_id, dependent: :destroy
```

---

### 7. Notification Model

**Modify:** `app/models/notification.rb`

Update TYPES:
```ruby
TYPES = %w[new_follower new_review review_like review_comment comment_like mention].freeze
```

Add notification method:
```ruby
def self.notify_mention(mentioned_user:, mentioner:, mentionable:)
  # Don't notify for self-mentions (shouldn't happen, but safety check)
  return if mentioned_user.id == mentioner.id

  create!(
    user: mentioned_user,
    notification_type: 'mention',
    actor: mentioner,
    notifiable: mentionable
  )
end
```

Add to `push_notification_content`:
```ruby
when 'mention'
  case notifiable
  when Review
    review = notifiable
    [
      'New Mention',
      "#{actor_name} mentioned you in a review of #{review.song_name}",
      { type: 'mention', notification_id: id.to_s, review_id: review.id.to_s }
    ]
  when ReviewComment
    comment = notifiable
    [
      'New Mention',
      "#{actor_name} mentioned you in a comment",
      { type: 'mention', notification_id: id.to_s, review_id: comment.review_id.to_s, comment_id: comment.id.to_s }
    ]
  else
    [nil, nil, {}]
  end
```

---

### 8. NotificationsController

**Modify:** `app/controllers/notifications_controller.rb`

Add case in `notification_data`:
```ruby
when 'mention'
  case notification.notifiable
  when Review
    review = notification.notifiable
    data[:message] = "#{notification.actor&.display_name || 'Someone'} mentioned you in a review"
    data[:review] = {
      id: review.id,
      song_name: review.song_name,
      band_name: review.band_name
    }
  when ReviewComment
    comment = notification.notifiable
    review = comment.review
    data[:message] = "#{notification.actor&.display_name || 'Someone'} mentioned you in a comment"
    data[:review] = {
      id: review.id,
      song_name: review.song_name,
      band_name: review.band_name
    }
    data[:comment] = {
      id: comment.id,
      body: comment.body.truncate(50)
    }
  end
```

---

### 9. Review Serializer

**Modify:** `app/serializers/review_serializer.rb`

Add `formatted_review_text` and `mentions` to output:
```ruby
def self.full(review, current_user: nil)
  # ... existing code ...

  data[:review_text] = review.review_text  # Original text
  data[:formatted_review_text] = format_with_mentions(review)  # With mention links
  data[:mentions] = serialize_mentions(review.mentions)

  # ... rest of serializer
end

def self.format_with_mentions(review)
  MentionService.format_content(review.review_text, review.mentions.includes(:user))
end

def self.serialize_mentions(mentions)
  mentions.includes(:user).map do |mention|
    {
      user_id: mention.user_id,
      username: mention.user.username,
      display_name: mention.user.display_name
    }
  end
end
```

---

### 10. ReviewCommentsController

**Modify:** `app/controllers/review_comments_controller.rb`

Update `serialize_comment`:
```ruby
def serialize_comment(comment)
  {
    id: comment.id,
    body: comment.body,  # Original text
    formatted_body: MentionService.format_content(comment.body, comment.mentions.includes(:user)),
    mentions: comment.mentions.includes(:user).map do |mention|
      {
        user_id: mention.user_id,
        username: mention.user.username,
        display_name: mention.user.display_name
      }
    end,
    author: {
      id: comment.user.id,
      username: comment.user.username,
      display_name: comment.user.display_name,
      profile_image_url: UserSerializer.profile_image_url(comment.user)
    },
    likes_count: comment.likes_count,
    liked_by_current_user: comment.liked_by?(current_user),
    created_at: comment.created_at,
    updated_at: comment.updated_at
  }
end
```

---

### 11. Username Search Endpoint (Optional but Recommended)

**Create:** `app/controllers/user_search_controller.rb`

For autocomplete when typing `@`:

```ruby
class UserSearchController < ApplicationController
  before_action :authenticate_request

  # GET /users/search?q=john
  def index
    query = params[:q].to_s.strip.downcase
    return json_response({ users: [] }) if query.length < 2

    users = User.where(disabled: false)
                .where('LOWER(username) LIKE ?', "#{query}%")
                .where.not(id: current_user.id)
                .limit(10)
                .select(:id, :username, :display_name)

    json_response({
      users: users.map do |user|
        {
          id: user.id,
          username: user.username,
          display_name: user.display_name,
          profile_image_url: UserSerializer.profile_image_url(user)
        }
      end
    })
  end
end
```

**Add route:**
```ruby
get '/users/search', to: 'user_search#index'
```

---

## API Response Format

### Mention Link Format

Mentions are formatted as markdown-style links for easy client parsing:

```
Original: "Great song @johndoe! @janedoe should check this out"
Formatted: "Great song [@johndoe](user:123)! [@janedoe](user:456) should check this out"
```

Clients can:
1. Parse the `[text](user:id)` pattern
2. Render as clickable links to `/users/{username}` or use the ID directly
3. Use the `mentions` array for additional user data (display names, profile images)

---

## API Response Examples

### Comment with Mentions

```json
{
  "id": 1,
  "body": "Hey @johndoe check this out!",
  "formatted_body": "Hey [@johndoe](user:123) check this out!",
  "mentions": [
    {
      "user_id": 123,
      "username": "johndoe",
      "display_name": "John Doe"
    }
  ],
  "author": { ... },
  "likes_count": 5,
  "liked_by_current_user": false,
  "created_at": "...",
  "updated_at": "..."
}
```

### Mention Notification

```json
{
  "id": 50,
  "type": "mention",
  "read": false,
  "created_at": "...",
  "actor": {
    "id": 1,
    "username": "musicfan",
    "display_name": "Music Fan",
    "profile_image_url": "..."
  },
  "message": "Music Fan mentioned you in a comment",
  "review": {
    "id": 10,
    "song_name": "Karma Police",
    "band_name": "Radiohead"
  },
  "comment": {
    "id": 5,
    "body": "Hey @johndoe check this out!"
  }
}
```

### Error Responses

**Invalid username (422 Unprocessable Entity):**
```json
{
  "error": "Looks like you tagged a user that doesn't exist: @fakeuser"
}
```

**Too many mentions (422 Unprocessable Entity):**
```json
{
  "error": "You can only mention up to 10 users per post"
}
```

---

## Implementation Order

1. Run migration to create mentions table
2. Create Mention model
3. Create MentionService
4. Update Review model (association + callback)
5. Update ReviewComment model (association + callback)
6. Update User model (associations)
7. Update Notification model (type + method + push content)
8. Update NotificationsController
9. Update review serialization
10. Update ReviewCommentsController serialization
11. (Optional) Create user search endpoint for autocomplete
12. Update API documentation

---

## Edge Cases Handled

1. **Self-mentions**: Filtered out, no notification sent
2. **Disabled users**: Not matched, not notified
3. **Non-existent usernames**: Silently ignored (no error, just no link)
4. **Duplicate mentions**: Same user mentioned twice = one mention record, one notification
5. **Edited content**: Mentions sync on update (removed mentions get deleted, new ones added)
6. **Case insensitivity**: @JohnDoe and @johndoe match the same user

---

## Future Extensibility

The polymorphic `mentionable` design allows mentions to work with:
- Reviews (implemented)
- ReviewComments (implemented)
- Future: Direct messages, band posts, event descriptions, etc.

Just add `has_many :mentions, as: :mentionable` and the `after_save` callback to any new model.

---

## Design Decisions

1. **Mention limit**: Maximum 10 mentions per post/comment
2. **Invalid username handling**: Return error "Looks like you tagged a user that doesn't exist"
3. **Link format**: Markdown-style `[@username](user:id)` - easy to parse in both Next.js and React Native with a simple regex
