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
      reviews_count: band.reviews.count,
      user_owned: band.user_owned?
    }
  end

  def self.full(band)
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
      apple_music_link: band.apple_music_link,
      youtube_music_link: band.youtube_music_link,
      about: band.about,
      profile_picture_url: band_image_url(band),
      reviews_count: band.reviews.count,
      user_owned: band.user_owned?,
      owner: band.user ? { id: band.user.id, username: band.user.username } : nil,
      created_at: band.created_at,
      updated_at: band.updated_at
    }
  end

  # Returns uploaded profile picture if present, otherwise falls back to Spotify image
  def self.band_image_url(band)
    profile_picture_url(band) || band.spotify_image_url
  end

  def self.with_reviews(band)
    # Only include reviews from active (non-disabled) users
    active_reviews = QueryService.band_reviews_from_active_users(band)
    upcoming_events = band.events.active.upcoming.includes(:venue).limit(10)

    full(band).merge(
      reviews: active_reviews.map do |review|
        ReviewSerializer.with_author(review)
      end,
      upcoming_events: upcoming_events.map do |event|
        EventSerializer.summary(event)
      end
    )
  end
end