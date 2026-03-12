class BandSerializer
  include ImageSerializable
  extend ImageUrlHelper

  def self.summary(band)
    {
      id: band.id,
      slug: band.slug,
      name: band.name,
      location: band.location,
      profile_picture_url: band_image_url(band),
      reviews_count: band.reviews_count,
      user_owned: band.user_owned?
    }
  end

  def self.full(band, current_user: nil)
    {
      id: band.id,
      slug: band.slug,
      name: band.name,
      city: band.city,
      region: band.region,
      location: band.location,
      latitude: band.latitude,
      longitude: band.longitude,
      spotify_link: band.spotify_link,
      bandcamp_link: band.bandcamp_link,
      bandcamp_embed: band.bandcamp_embed,
      apple_music_link: band.apple_music_link,
      youtube_music_link: band.youtube_music_link,
      soundcloud_link: band.soundcloud_link,
      preferred_band_link: preferred_link_for(band, current_user),
      musicbrainz_id: band.musicbrainz_id,
      lastfm_artist_name: band.lastfm_artist_name,
      lastfm_url: band.lastfm_url,
      about: band.about,
      profile_picture_url: band_image_url(band),
      reviews_count: band.reviews_count,
      user_owned: band.user_owned?,
      owner: band.user ? { id: band.user.id, username: band.user.username } : nil,
      # Social links
      social_links: social_links(band),
      created_at: band.created_at,
      updated_at: band.updated_at
    }
  end

  # Returns hash of configured social links
  def self.social_links(band)
    links = {}
    %w[instagram threads bluesky twitter tumblr tiktok facebook youtube].each do |platform|
      field = "#{platform}_url"
      value = band.send(field) if band.respond_to?(field)
      links[platform] = value if value.present?
    end
    links
  end

  # Returns the band's link for the user's preferred streaming platform
  def self.preferred_link_for(band, user)
    return nil unless user&.preferred_streaming_platform.present?

    case user.preferred_streaming_platform
    when 'spotify' then band.spotify_link
    when 'appleMusic' then band.apple_music_link
    when 'bandcamp' then band.bandcamp_link
    when 'youtubeMusic' then band.youtube_music_link
    when 'soundcloud' then band.soundcloud_link
    end
  end

  # Returns uploaded profile picture if present, otherwise falls back to artist image
  # Uses cached version when available, queues caching for eligible external URLs
  def self.band_image_url(band)
    profile_picture_url(band) || band.resolved_artist_image_url
  end

  def self.with_reviews(band, current_user: nil)
    # Only include reviews from active (non-disabled) users
    active_reviews = QueryService.band_reviews_from_active_users(band)
    upcoming_events = band.events.active.upcoming.includes(:venue).limit(10)

    full(band, current_user: current_user).merge(
      reviews: active_reviews.map do |review|
        ReviewSerializer.with_author(review, current_user: current_user)
      end,
      upcoming_events: upcoming_events.map do |event|
        EventSerializer.summary(event)
      end
    )
  end
end