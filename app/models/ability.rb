class Ability < ApplicationRecord
  has_many :plan_abilities, dependent: :destroy
  has_many :plans, through: :plan_abilities

  CATEGORIES = %w[content monetization audience social analytics band].freeze

  validates :key, presence: true, uniqueness: true
  validates :name, presence: true
  validates :category, presence: true, inclusion: { in: CATEGORIES }

  scope :by_category, ->(category) { where(category: category) }
  scope :ordered, -> { order(:category, :name) }
end
