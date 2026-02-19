# frozen_string_literal: true

class DeviceToken < ApplicationRecord
  belongs_to :user

  validates :token, presence: true, uniqueness: true
  validates :platform, presence: true, inclusion: { in: %w[ios android] }

  scope :active, -> { where('last_used_at > ?', 30.days.ago) }
  scope :for_platform, ->(platform) { where(platform: platform) }

  # Update last_used_at timestamp
  def touch_last_used
    update_column(:last_used_at, Time.current)
  end
end
