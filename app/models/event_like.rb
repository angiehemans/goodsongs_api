class EventLike < ApplicationRecord
  belongs_to :user
  belongs_to :event, counter_cache: true

  validates :user_id, uniqueness: { scope: :event_id, message: 'has already liked this event' }
end
