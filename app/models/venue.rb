class Venue < ApplicationRecord
  has_many :events, dependent: :nullify

  geocoded_by :full_address
  after_validation :geocode, if: :should_geocode?

  validates :name, presence: true
  validates :address, presence: true

  def full_address
    [address, city, region].compact.reject(&:blank?).join(', ')
  end

  private

  def should_geocode?
    (address_changed? || city_changed? || region_changed?) && address.present?
  end
end
