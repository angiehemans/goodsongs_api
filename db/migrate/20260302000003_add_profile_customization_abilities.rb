class AddProfileCustomizationAbilities < ActiveRecord::Migration[8.0]
  def up
    # Create new abilities for profile customization
    abilities = {}

    abilities_data.each do |attrs|
      ability = Ability.find_or_create_by!(key: attrs[:key]) do |a|
        a.name = attrs[:name]
        a.description = attrs[:description]
        a.category = attrs[:category]
      end
      abilities[attrs[:key]] = ability
    end

    # Grant abilities to plans
    plan_abilities_map.each do |plan_key, ability_keys|
      plan = Plan.find_by(key: plan_key)
      next unless plan

      ability_keys.each do |ability_key|
        ability = abilities[ability_key]
        next unless ability
        PlanAbility.find_or_create_by!(plan: plan, ability: ability)
      end
    end
  end

  def down
    # Remove the abilities (cascade will remove plan_abilities)
    Ability.where(key: %w[can_customize_profile profile_mailing_list_section profile_merch_section]).destroy_all
  end

  private

  def abilities_data
    [
      {
        key: "can_customize_profile",
        name: "Customize Profile",
        description: "Customize public profile with theming and section ordering",
        category: "content"
      },
      {
        key: "profile_mailing_list_section",
        name: "Profile Mailing List Section",
        description: "Add a mailing list signup section to profile",
        category: "content"
      },
      {
        key: "profile_merch_section",
        name: "Profile Merch Section",
        description: "Add a merchandise section to profile",
        category: "content"
      }
    ]
  end

  def plan_abilities_map
    {
      # Band Starter gets base customization
      "band_starter" => %w[can_customize_profile],

      # Band Pro gets full customization including mailing list and merch
      "band_pro" => %w[can_customize_profile profile_mailing_list_section profile_merch_section],

      # Blogger gets base customization
      "blogger" => %w[can_customize_profile],

      # Blogger Pro gets customization and mailing list (no merch)
      "blogger_pro" => %w[can_customize_profile profile_mailing_list_section]
    }
  end
end
