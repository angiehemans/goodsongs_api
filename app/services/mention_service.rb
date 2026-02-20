# frozen_string_literal: true

class MentionService
  MENTION_REGEX = /@([a-zA-Z0-9_]+)/
  MAX_MENTIONS = 10

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
    invalid = usernames.reject do |u|
      found_usernames.include?(u) || u == @mentioner.username&.downcase
    end

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
