# app/models/user.rb
class User < ApplicationRecord
  has_secure_password
  has_many :reviews, dependent: :destroy
  has_many :bands, dependent: :destroy
  has_many :scrobbles, dependent: :destroy
  has_many :submitted_bands, class_name: 'Band', foreign_key: :submitted_by_id, dependent: :nullify
  has_many :submitted_albums, class_name: 'Album', foreign_key: :submitted_by_id, dependent: :nullify
  has_many :submitted_tracks, class_name: 'Track', foreign_key: :submitted_by_id, dependent: :nullify
  has_one_attached :profile_image
  belongs_to :primary_band, class_name: 'Band', optional: true

  # Follow associations
  has_many :active_follows, class_name: 'Follow', foreign_key: 'follower_id', dependent: :destroy
  has_many :passive_follows, class_name: 'Follow', foreign_key: 'followed_id', dependent: :destroy
  has_many :following, through: :active_follows, source: :followed
  has_many :followers, through: :passive_follows, source: :follower

  # Notifications
  has_many :notifications, dependent: :destroy

  # Review likes
  has_many :review_likes, dependent: :destroy
  has_many :liked_reviews, through: :review_likes, source: :review

  # Geocoding for user location
  geocoded_by :full_location
  after_validation :geocode, if: :should_geocode?

  # Token expiration constants
  EMAIL_CONFIRMATION_EXPIRY = 24.hours
  PASSWORD_RESET_EXPIRY = 2.hours

  enum :account_type, { fan: 0, band: 1 }

  validates :email, presence: true, uniqueness: { case_sensitive: false }
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :password, length: { minimum: 6 }, if: -> { new_record? || !password.nil? }
  validates :about_me, length: { maximum: 500 }
  validates :city, length: { maximum: 100 }, allow_blank: true
  validates :region, length: { maximum: 100 }, allow_blank: true

  # Username is only required for FAN accounts after onboarding
  validates :username, presence: true, if: :username_required?
  validates :username, uniqueness: { case_sensitive: false }, allow_blank: true
  validates :username, format: { with: /\A[a-zA-Z0-9_]+\z/, message: "only allows letters, numbers, and underscores" }, allow_blank: true

  # Account type required once onboarding is complete
  validates :account_type, presence: true, if: :onboarding_completed?

  # BAND accounts must have a primary band after onboarding
  validates :primary_band, presence: true, if: :primary_band_required?

  before_save :downcase_email, :downcase_username
  after_create :send_confirmation_email

  def profile_data
    UserSerializer.profile_data(self)
  end

  def public_profile_data
    UserSerializer.public_profile(self)
  end

  # Display name: username for fans, band name for bands
  def display_name
    if band?
      primary_band&.name || email.split('@').first
    else
      username || email.split('@').first
    end
  end

  # Check if user can modify a resource (owner or admin)
  def can_modify?(resource)
    return true if admin?
    return resource.user_id == id if resource.respond_to?(:user_id)
    return resource.id == id if resource.is_a?(User)
    false
  end

  # Full location string for geocoding
  def full_location
    [city, region].compact.reject(&:blank?).join(', ')
  end

  # Check if user has a location set
  def has_location?
    city.present? || region.present?
  end

  # Location display string
  def location
    full_location.presence
  end

  # Follow a user
  def follow(other_user)
    following << other_user unless following?(other_user)
  end

  # Unfollow a user
  def unfollow(other_user)
    following.delete(other_user)
  end

  # Check if following a user
  def following?(other_user)
    following.include?(other_user)
  end

  # Like a review
  def like_review(review)
    liked_reviews << review unless likes_review?(review)
  end

  # Unlike a review
  def unlike_review(review)
    liked_reviews.delete(review)
  end

  # Check if user likes a review
  def likes_review?(review)
    liked_reviews.include?(review)
  end

  # Check if Last.fm account is connected
  def lastfm_connected?
    lastfm_username.present?
  end

  # Email confirmation token generation
  def generate_email_confirmation_token!
    loop do
      self.email_confirmation_token = SecureRandom.urlsafe_base64(32)
      break unless User.exists?(email_confirmation_token: email_confirmation_token)
    end
    self.email_confirmation_sent_at = Time.current
    save!
    email_confirmation_token
  end

  # Password reset token generation
  def generate_password_reset_token!
    loop do
      self.password_reset_token = SecureRandom.urlsafe_base64(32)
      break unless User.exists?(password_reset_token: password_reset_token)
    end
    self.password_reset_sent_at = Time.current
    save!
    password_reset_token
  end

  # Check if email confirmation token is still valid
  def email_confirmation_token_valid?
    email_confirmation_token.present? &&
      email_confirmation_sent_at.present? &&
      email_confirmation_sent_at > EMAIL_CONFIRMATION_EXPIRY.ago
  end

  # Check if password reset token is still valid
  def password_reset_token_valid?
    password_reset_token.present? &&
      password_reset_sent_at.present? &&
      password_reset_sent_at > PASSWORD_RESET_EXPIRY.ago
  end

  # Confirm email and clear token
  def confirm_email!
    update!(
      email_confirmed: true,
      email_confirmation_token: nil,
      email_confirmation_sent_at: nil
    )
  end

  # Clear password reset token after use
  def clear_password_reset_token!
    update!(
      password_reset_token: nil,
      password_reset_sent_at: nil
    )
  end

  # Check if user can request another confirmation email (rate limit: 1 minute)
  def can_resend_confirmation?
    return false if email_confirmed?
    return true if email_confirmation_sent_at.nil?
    email_confirmation_sent_at < 1.minute.ago
  end

  # Check if user can request password reset (rate limit: 1 minute)
  def can_request_password_reset?
    return true if password_reset_sent_at.nil?
    password_reset_sent_at < 1.minute.ago
  end

  private

  # Only geocode if location fields changed and we have location data
  def should_geocode?
    (city_changed? || region_changed?) && full_location.present?
  end

  def username_required?
    fan? && onboarding_completed?
  end

  def primary_band_required?
    band? && onboarding_completed?
  end

  def downcase_email
    self.email = email.downcase
  end

  def downcase_username
    self.username = username&.downcase
  end

  def send_confirmation_email
    generate_email_confirmation_token!
    UserMailerJob.perform_later(id, :confirmation)
  end
end
