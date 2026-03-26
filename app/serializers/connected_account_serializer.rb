class ConnectedAccountSerializer
  def self.full(account)
    {
      platform: account.platform,
      platform_username: account.platform_username,
      account_type: account.account_type,
      auto_post_recommendations: account.auto_post_recommendations,
      auto_post_band_posts: account.auto_post_band_posts,
      auto_post_events: account.auto_post_events,
      needs_reauth: account.needs_reauth,
      created_at: account.created_at,
      updated_at: account.updated_at
    }
  end
end
