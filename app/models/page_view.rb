# frozen_string_literal: true

class PageView < ApplicationRecord
  VALID_VIEWABLE_TYPES = %w[Post Band Event CustomPage].freeze
  VALID_DEVICE_TYPES = %w[desktop mobile tablet].freeze

  belongs_to :viewable, polymorphic: true
  belongs_to :owner, class_name: 'User'

  validates :viewable_type, inclusion: { in: VALID_VIEWABLE_TYPES }
  validates :path, :session_id, :ip_hash, presence: true
  validates :device_type, inclusion: { in: VALID_DEVICE_TYPES }

  scope :for_owner, ->(user) { where(owner_id: user.id) }
  scope :in_period, ->(start_time, end_time) { where(created_at: start_time..end_time) }
  scope :by_referrer_source, ->(source) { where(referrer_source: source) }
  scope :by_device_type, ->(device_type) { where(device_type: device_type) }
  scope :by_country, ->(country) { where(country: country) }

  def self.unique_sessions_count
    distinct.count(:session_id)
  end
end
