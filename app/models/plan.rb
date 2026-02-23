class Plan < ApplicationRecord
  has_many :plan_abilities, dependent: :destroy
  has_many :abilities, through: :plan_abilities
  has_many :users, dependent: :restrict_with_error

  validates :key, presence: true, uniqueness: true
  validates :name, presence: true
  validates :role, presence: true, inclusion: { in: %w[fan band blogger] }

  scope :active, -> { where(active: true) }
  scope :for_role, ->(role) { where(role: role) }

  def self.default_for_role(role)
    case role.to_s
    when "fan" then find_by(key: "fan_free")
    when "band" then find_by(key: "band_free")
    when "blogger" then find_by(key: "blogger")
    end
  end

  def free?
    price_cents_monthly.zero?
  end
end
