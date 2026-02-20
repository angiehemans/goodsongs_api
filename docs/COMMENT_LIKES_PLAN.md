# Comment Likes Feature Plan

## Overview

Add the ability for users to like comments on reviews, similar to how they can like reviews.

---

## Files to Create

### 1. Database Migration

**Create:** `db/migrate/YYYYMMDDHHMMSS_create_review_comment_likes.rb`

```ruby
class CreateReviewCommentLikes < ActiveRecord::Migration[8.0]
  def change
    create_table :review_comment_likes do |t|
      t.references :user, null: false, foreign_key: true
      t.references :review_comment, null: false, foreign_key: true
      t.timestamps
    end

    add_index :review_comment_likes, [:user_id, :review_comment_id], unique: true
  end
end
```

---

### 2. ReviewCommentLike Model

**Create:** `app/models/review_comment_like.rb`

```ruby
class ReviewCommentLike < ApplicationRecord
  belongs_to :user
  belongs_to :review_comment

  validates :user_id, uniqueness: {
    scope: :review_comment_id,
    message: 'has already liked this comment'
  }
end
```

---

### 3. ReviewCommentLikesController

**Create:** `app/controllers/review_comment_likes_controller.rb`

```ruby
class ReviewCommentLikesController < ApplicationController
  before_action :authenticate_request
  before_action :set_comment

  # POST /comments/:comment_id/like
  def create
    if current_user.likes_comment?(@comment)
      return json_response({ error: "You have already liked this comment" }, :unprocessable_entity)
    end

    current_user.like_comment(@comment)

    # Optional: Notify the comment author
    Notification.notify_comment_like(comment: @comment, liker: current_user)

    json_response({
      message: "Comment liked successfully",
      liked: true,
      likes_count: @comment.likes_count
    })
  end

  # DELETE /comments/:comment_id/like
  def destroy
    unless current_user.likes_comment?(@comment)
      return json_response({ error: "You have not liked this comment" }, :unprocessable_entity)
    end

    current_user.unlike_comment(@comment)

    json_response({
      message: "Comment unliked successfully",
      liked: false,
      likes_count: @comment.likes_count
    })
  end

  private

  def set_comment
    @comment = ReviewComment.find(params[:comment_id])
  end
end
```

---

## Files to Modify

### 4. ReviewComment Model

**Modify:** `app/models/review_comment.rb`

```ruby
class ReviewComment < ApplicationRecord
  belongs_to :user
  belongs_to :review
  has_many :review_comment_likes, dependent: :destroy
  has_many :likers, through: :review_comment_likes, source: :user

  validates :body, presence: true, length: { maximum: 300 }

  scope :chronological, -> { order(created_at: :asc) }
  scope :reverse_chronological, -> { order(created_at: :desc) }

  def likes_count
    review_comment_likes.count
  end

  def liked_by?(user)
    return false unless user
    review_comment_likes.exists?(user_id: user.id)
  end
end
```

---

### 5. User Model

**Modify:** `app/models/user.rb`

Add after `has_many :review_comments`:

```ruby
# Comment likes
has_many :review_comment_likes, dependent: :destroy
has_many :liked_comments, through: :review_comment_likes, source: :review_comment
```

Add helper methods (can go near the review like methods):

```ruby
# Like a comment
def like_comment(comment)
  liked_comments << comment unless likes_comment?(comment)
end

# Unlike a comment
def unlike_comment(comment)
  liked_comments.delete(comment)
end

# Check if user likes a comment
def likes_comment?(comment)
  liked_comments.include?(comment)
end
```

---

### 6. Routes

**Modify:** `config/routes.rb`

Add after the review comments routes:

```ruby
# Comment likes
post '/comments/:comment_id/like', to: 'review_comment_likes#create'
delete '/comments/:comment_id/like', to: 'review_comment_likes#destroy'
```

---

### 7. Notification Model (Optional)

**Modify:** `app/models/notification.rb`

Add `comment_like` to TYPES:

```ruby
TYPES = %w[new_follower new_review review_like review_comment comment_like].freeze
```

Add notification method:

```ruby
def self.notify_comment_like(comment:, liker:)
  # Don't notify if the liker is the comment author
  return if comment.user_id == liker.id

  create!(
    user: comment.user,
    notification_type: 'comment_like',
    actor: liker,
    notifiable: comment
  )
end
```

Update `push_notification_content` private method to handle the new type:

```ruby
when 'comment_like'
  comment = notifiable
  return [nil, nil, {}] unless comment.is_a?(ReviewComment)

  [
    'New Like',
    "#{actor_name} liked your comment",
    { type: 'comment_like', notification_id: id.to_s, comment_id: comment.id.to_s, review_id: comment.review_id.to_s }
  ]
```

---

### 8. ReviewCommentsController - Update Serialization

**Modify:** `app/controllers/review_comments_controller.rb`

Update `serialize_comment` method:

```ruby
def serialize_comment(comment)
  {
    id: comment.id,
    body: comment.body,
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

### 9. NotificationsController - Handle New Type

**Modify:** `app/controllers/notifications_controller.rb`

Add case for `comment_like` in `notification_data` method:

```ruby
when 'comment_like'
  if notification.notifiable.is_a?(ReviewComment)
    comment = notification.notifiable
    review = comment.review
    data[:message] = "#{notification.actor&.display_name || 'Someone'} liked your comment"
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

## API Endpoints

### POST /comments/:comment_id/like

Like a comment.

**Authentication:** Required

**Response (200 OK):**
```json
{
  "message": "Comment liked successfully",
  "liked": true,
  "likes_count": 5
}
```

---

### DELETE /comments/:comment_id/like

Unlike a comment.

**Authentication:** Required

**Response (200 OK):**
```json
{
  "message": "Comment unliked successfully",
  "liked": false,
  "likes_count": 4
}
```

---

## Updated Comment Response

Comments will now include:

```json
{
  "id": 1,
  "body": "Great review!",
  "author": { ... },
  "likes_count": 5,
  "liked_by_current_user": true,
  "created_at": "...",
  "updated_at": "..."
}
```

---

## Implementation Order

1. Run migration
2. Create `ReviewCommentLike` model
3. Update `ReviewComment` model
4. Update `User` model
5. Create `ReviewCommentLikesController`
6. Add routes
7. Update `ReviewCommentsController` serialization
8. (Optional) Add notification support
9. Update API documentation

---

## Questions to Consider

1. **Notifications:** Should users be notified when their comment is liked? (Plan includes it as optional)
2. **Counter Cache:** Should we add a `likes_count` column to `review_comments` for performance? (Current plan calculates dynamically like reviews do)
