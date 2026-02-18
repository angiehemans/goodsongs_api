class Follow < ApplicationRecord
  belongs_to :follower, class_name: 'User', counter_cache: :following_count
  belongs_to :followed, class_name: 'User', counter_cache: :followers_count

  validates :follower_id, uniqueness: { scope: :followed_id, message: 'is already following this user' }
end
