class PlanSerializer
  def self.summary(plan)
    {
      key: plan.key,
      name: plan.name
    }
  end

  def self.full(plan)
    {
      id: plan.id,
      key: plan.key,
      name: plan.name,
      role: plan.role,
      price_cents_monthly: plan.price_cents_monthly,
      price_cents_annual: plan.price_cents_annual,
      active: plan.active,
      abilities_count: plan.abilities.count,
      created_at: plan.created_at,
      updated_at: plan.updated_at
    }
  end

  def self.with_abilities(plan)
    full(plan).merge(
      abilities: plan.abilities.ordered.map { |a| AbilitySerializer.summary(a) }
    )
  end
end
