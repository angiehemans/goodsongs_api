class AddBlogAbilitiesToBandPlans < ActiveRecord::Migration[8.0]
  def up
    # Find or verify abilities exist
    abilities = {}
    %w[create_blog_post attach_images attach_songs draft_posts manage_tags rss_feed schedule_post].each do |key|
      ability = Ability.find_by(key: key)
      abilities[key] = ability if ability
    end

    # Add blog abilities to band_starter plan
    band_starter = Plan.find_by(key: 'band_starter')
    if band_starter
      starter_abilities = %w[create_blog_post attach_images attach_songs draft_posts manage_tags rss_feed]
      starter_abilities.each do |ability_key|
        ability = abilities[ability_key]
        next unless ability
        PlanAbility.find_or_create_by!(plan: band_starter, ability: ability)
      end
    end

    # Add blog abilities to band_pro plan (includes schedule_post)
    band_pro = Plan.find_by(key: 'band_pro')
    if band_pro
      pro_abilities = %w[create_blog_post attach_images attach_songs draft_posts manage_tags rss_feed schedule_post]
      pro_abilities.each do |ability_key|
        ability = abilities[ability_key]
        next unless ability
        PlanAbility.find_or_create_by!(plan: band_pro, ability: ability)
      end
    end
  end

  def down
    # Remove blog abilities from band_starter plan
    band_starter = Plan.find_by(key: 'band_starter')
    if band_starter
      %w[create_blog_post attach_images attach_songs draft_posts manage_tags rss_feed].each do |ability_key|
        ability = Ability.find_by(key: ability_key)
        next unless ability
        PlanAbility.where(plan: band_starter, ability: ability).destroy_all
      end
    end

    # Remove blog abilities from band_pro plan
    band_pro = Plan.find_by(key: 'band_pro')
    if band_pro
      %w[create_blog_post attach_images attach_songs draft_posts manage_tags rss_feed schedule_post].each do |ability_key|
        ability = Ability.find_by(key: ability_key)
        next unless ability
        PlanAbility.where(plan: band_pro, ability: ability).destroy_all
      end
    end
  end
end
