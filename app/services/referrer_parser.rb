# frozen_string_literal: true

class ReferrerParser
  SEARCH_ENGINES = {
    'google' => /google\./i,
    'bing' => /bing\./i,
    'duckduckgo' => /duckduckgo\./i,
    'yahoo' => /yahoo\./i,
    'yandex' => /yandex\./i,
    'baidu' => /baidu\./i
  }.freeze

  SOCIAL_NETWORKS = {
    'facebook' => /facebook\.|fb\./i,
    'instagram' => /instagram\./i,
    'twitter' => /twitter\.|t\.co|x\.com/i,
    'tiktok' => /tiktok\./i,
    'linkedin' => /linkedin\./i,
    'reddit' => /reddit\./i,
    'youtube' => /youtube\.|youtu\.be/i,
    'pinterest' => /pinterest\./i,
    'threads' => /threads\.net/i,
    'bluesky' => /bsky\.app/i,
    'mastodon' => /mastodon\.|mstdn\./i
  }.freeze

  MUSIC_PLATFORMS = {
    'spotify' => /spotify\./i,
    'apple_music' => /music\.apple\./i,
    'bandcamp' => /bandcamp\./i,
    'soundcloud' => /soundcloud\./i,
    'lastfm' => /last\.fm/i
  }.freeze

  class << self
    def parse(referrer_url)
      return 'direct' if referrer_url.blank?

      begin
        uri = URI.parse(referrer_url.to_s)
        host = uri.host.to_s.downcase
      rescue URI::InvalidURIError
        return 'other'
      end

      return 'direct' if host.blank?

      # Check for internal referrer (goodsongs)
      return 'goodsongs' if goodsongs_host?(host)

      # Check search engines
      SEARCH_ENGINES.each do |source, pattern|
        return source if host.match?(pattern)
      end

      # Check social networks
      SOCIAL_NETWORKS.each do |source, pattern|
        return source if host.match?(pattern)
      end

      # Check music platforms
      MUSIC_PLATFORMS.each do |source, pattern|
        return source if host.match?(pattern)
      end

      # Return the domain as source for unknown referrers
      'other'
    end

    private

    def goodsongs_host?(host)
      host.include?('goodsongs') ||
        host.include?('localhost') ||
        host == '127.0.0.1'
    end
  end
end
