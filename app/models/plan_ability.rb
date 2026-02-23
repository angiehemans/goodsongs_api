class PlanAbility < ApplicationRecord
  belongs_to :plan
  belongs_to :ability

  validates :plan_id, uniqueness: { scope: :ability_id }
end
