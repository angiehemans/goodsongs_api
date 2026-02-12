# frozen_string_literal: true

class RefreshToken < ApplicationRecord
  # Token expires after 90 days
  EXPIRATION_PERIOD = 90.days

  belongs_to :user

  validates :token_digest, presence: true, uniqueness: true
  validates :expires_at, presence: true

  scope :active, -> { where(revoked_at: nil).where('expires_at > ?', Time.current) }
  scope :expired, -> { where('expires_at <= ?', Time.current) }
  scope :revoked, -> { where.not(revoked_at: nil) }

  # Generate a new refresh token for a user
  # Returns the raw token (to send to client) and creates the record
  def self.generate_for(user, request: nil, device_name: nil)
    raw_token = SecureRandom.urlsafe_base64(64)

    refresh_token = create!(
      user: user,
      token_digest: digest(raw_token),
      expires_at: EXPIRATION_PERIOD.from_now,
      device_name: device_name,
      device_type: detect_device_type(request),
      ip_address: request&.remote_ip,
      user_agent: request&.user_agent&.truncate(500)
    )

    [raw_token, refresh_token]
  end

  # Find a valid (non-revoked, non-expired) token
  def self.find_by_token(raw_token)
    return nil if raw_token.blank?

    active.find_by(token_digest: digest(raw_token))
  end

  # Hash the token for storage
  def self.digest(token)
    Digest::SHA256.hexdigest(token)
  end

  # Revoke this token
  def revoke!
    update!(revoked_at: Time.current)
  end

  # Check if token is valid
  def valid_token?
    revoked_at.nil? && expires_at > Time.current
  end

  # Check if token is expired
  def expired?
    expires_at <= Time.current
  end

  # Check if token is revoked
  def revoked?
    revoked_at.present?
  end

  # Revoke all tokens for a user (e.g., on password change)
  def self.revoke_all_for_user(user)
    where(user: user).active.update_all(revoked_at: Time.current)
  end

  # Clean up old expired/revoked tokens (run periodically)
  def self.cleanup_old_tokens(older_than: 7.days.ago)
    where('expires_at < ? OR revoked_at < ?', older_than, older_than).delete_all
  end

  private

  def self.detect_device_type(request)
    return nil unless request&.user_agent

    user_agent = request.user_agent.downcase

    if user_agent.include?('mobile') || user_agent.include?('android') || user_agent.include?('iphone')
      'mobile'
    elsif user_agent.include?('tablet') || user_agent.include?('ipad')
      'tablet'
    else
      'web'
    end
  end
end
