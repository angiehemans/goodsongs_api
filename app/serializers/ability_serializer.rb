class AbilitySerializer
  def self.summary(ability)
    {
      key: ability.key,
      name: ability.name,
      category: ability.category
    }
  end

  def self.full(ability)
    {
      id: ability.id,
      key: ability.key,
      name: ability.name,
      description: ability.description,
      category: ability.category,
      plans: ability.plans.map { |p| { key: p.key, name: p.name } },
      created_at: ability.created_at,
      updated_at: ability.updated_at
    }
  end
end
