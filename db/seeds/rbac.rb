# db/seeds/rbac.rb
# Seeds for Roles, Plans & Abilities System
#
# NOTE: RBAC data is now created via migration (20260223094000_seed_rbac_data.rb)
# This file is kept for manual re-seeding if needed, but the migration is the
# primary source of truth for production deployments.

puts "Seeding RBAC data..."

# Skip if data already exists (from migration)
if Plan.exists? && Ability.exists?
  puts "  RBAC data already exists (#{Plan.count} plans, #{Ability.count} abilities)"
  puts "  Skipping seed - data was created by migration"
  return
end

puts "  Creating RBAC data..."

# =============================================================================
# ABILITIES
# =============================================================================

abilities_data = [
  # Content abilities
  { key: "create_recommendation", name: "Create Recommendation", description: "Recommend songs to followers", category: "content" },
  { key: "create_blog_post", name: "Create Blog Post", description: "Write and publish blog posts", category: "content" },
  { key: "attach_images", name: "Attach Images", description: "Add images to blog posts", category: "content" },
  { key: "attach_songs", name: "Attach Songs", description: "Embed songs with music player", category: "content" },
  { key: "draft_posts", name: "Draft Posts", description: "Save posts as drafts", category: "content" },
  { key: "schedule_post", name: "Schedule Posts", description: "Schedule posts for future publication", category: "content" },
  { key: "custom_pages", name: "Custom Pages", description: "Create About, Contact, etc.", category: "content" },
  { key: "manage_tags", name: "Manage Tags", description: "Tag, genre, and category management", category: "content" },
  { key: "rss_feed", name: "RSS Feed", description: "Public RSS feed for posts", category: "content" },
  { key: "seo_controls", name: "SEO Controls", description: "Meta descriptions, OG images, canonical URLs", category: "content" },

  # Monetization abilities
  { key: "manage_storefront", name: "Manage Storefront", description: "Sell merch and music", category: "monetization" },
  { key: "accept_donations", name: "Accept Donations", description: "Accept reader donations", category: "monetization" },
  { key: "manage_subscriptions", name: "Manage Subscriptions", description: "Paid reader subscriptions", category: "monetization" },

  # Audience abilities
  { key: "follow_users", name: "Follow Users", description: "Follow fans, bands, and bloggers", category: "audience" },
  { key: "create_comments", name: "Create Comments", description: "Comment on posts and recommendations", category: "audience" },
  { key: "send_newsletter", name: "Send Newsletter", description: "Mailing list management", category: "audience" },

  # Social abilities
  { key: "auto_post_instagram", name: "Auto Post Instagram", description: "Auto-post to Instagram", category: "social" },
  { key: "auto_post_threads", name: "Auto Post Threads", description: "Auto-post to Threads", category: "social" },
  { key: "instagram_display", name: "Instagram Display", description: "Display Instagram feed on profile", category: "social" },
  { key: "share_playlists", name: "Share Playlists", description: "Share playlists across platforms", category: "social" },
  { key: "scrobble_lastfm", name: "Last.fm Scrobbling", description: "Last.fm scrobbling integration", category: "social" },

  # Analytics abilities
  { key: "view_analytics", name: "View Analytics", description: "View page/profile analytics", category: "analytics" },

  # Band abilities
  { key: "manage_band_profile", name: "Manage Band Profile", description: "Edit band profile and bio", category: "band" },
  { key: "upload_music", name: "Upload Music", description: "Upload tracks", category: "band" },
  { key: "manage_events", name: "Manage Events", description: "Create and manage events", category: "band" },
  { key: "custom_design", name: "Custom Design", description: "Customize profile appearance", category: "band" }
]

abilities = {}
abilities_data.each do |attrs|
  ability = Ability.find_or_create_by!(key: attrs[:key]) do |a|
    a.name = attrs[:name]
    a.description = attrs[:description]
    a.category = attrs[:category]
  end
  abilities[attrs[:key]] = ability
end

puts "  Created #{Ability.count} abilities"

# =============================================================================
# PLANS
# =============================================================================

plans_data = [
  { key: "fan_free", name: "Fan Free", role: "fan", price_cents_monthly: 0, price_cents_annual: 0 },
  { key: "band_free", name: "Band Free", role: "band", price_cents_monthly: 0, price_cents_annual: 0 },
  { key: "band_starter", name: "Band Starter", role: "band", price_cents_monthly: 1500, price_cents_annual: 15600 },
  { key: "band_pro", name: "Band Pro", role: "band", price_cents_monthly: 4000, price_cents_annual: 40800 },
  { key: "blogger", name: "Blogger", role: "blogger", price_cents_monthly: 900, price_cents_annual: 9600 },
  { key: "blogger_pro", name: "Blogger Pro", role: "blogger", price_cents_monthly: 1800, price_cents_annual: 18000 }
]

plans = {}
plans_data.each do |attrs|
  plan = Plan.find_or_create_by!(key: attrs[:key]) do |p|
    p.name = attrs[:name]
    p.role = attrs[:role]
    p.price_cents_monthly = attrs[:price_cents_monthly]
    p.price_cents_annual = attrs[:price_cents_annual]
  end
  plans[attrs[:key]] = plan
end

puts "  Created #{Plan.count} plans"

# =============================================================================
# PLAN-ABILITY MAPPINGS
# =============================================================================

plan_abilities_map = {
  # Fan Free abilities
  "fan_free" => %w[
    create_recommendation
    follow_users
    create_comments
    scrobble_lastfm
  ],

  # Band Free abilities
  "band_free" => %w[
    create_recommendation
    follow_users
    create_comments
    manage_band_profile
    upload_music
  ],

  # Band Starter abilities (includes Band Free + more)
  "band_starter" => %w[
    create_recommendation
    follow_users
    create_comments
    manage_band_profile
    upload_music
    view_analytics
    manage_storefront
    send_newsletter
    manage_events
    custom_design
  ],

  # Band Pro abilities (includes Band Starter + more)
  "band_pro" => %w[
    create_recommendation
    follow_users
    create_comments
    manage_band_profile
    upload_music
    view_analytics
    manage_storefront
    send_newsletter
    manage_events
    custom_design
  ],

  # Blogger abilities
  "blogger" => %w[
    create_blog_post
    attach_images
    attach_songs
    draft_posts
    create_comments
    follow_users
    create_recommendation
    custom_design
    custom_pages
    seo_controls
    view_analytics
    manage_tags
    rss_feed
  ],

  # Blogger Pro abilities (includes Blogger + more)
  "blogger_pro" => %w[
    create_blog_post
    attach_images
    attach_songs
    draft_posts
    schedule_post
    create_comments
    follow_users
    create_recommendation
    custom_design
    custom_pages
    seo_controls
    view_analytics
    manage_tags
    rss_feed
    manage_storefront
    accept_donations
    manage_subscriptions
    send_newsletter
    manage_events
    share_playlists
    auto_post_instagram
    auto_post_threads
    instagram_display
  ]
}

plan_abilities_count = 0
plan_abilities_map.each do |plan_key, ability_keys|
  plan = plans[plan_key]
  ability_keys.each do |ability_key|
    ability = abilities[ability_key]
    if ability.nil?
      puts "  WARNING: Ability '#{ability_key}' not found for plan '#{plan_key}'"
      next
    end
    PlanAbility.find_or_create_by!(plan: plan, ability: ability)
    plan_abilities_count += 1
  end
end

puts "  Created #{PlanAbility.count} plan-ability mappings"
puts "RBAC seeding complete!"
