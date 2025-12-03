# app/models/user.rb
class User < ApplicationRecord
  has_secure_password
  has_many :reviews, dependent: :destroy
  has_many :bands, dependent: :destroy
  has_one_attached :profile_image
  belongs_to :primary_band, class_name: 'Band', optional: true

  # Geocoding for user location
  geocoded_by :full_location
  after_validation :geocode, if: :should_geocode?

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
end
