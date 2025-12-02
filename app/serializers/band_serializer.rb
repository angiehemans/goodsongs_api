class BandSerializer
  include ImageSerializable
  extend ImageUrlHelper

  def self.summary(band)
    {
      id: band.id,
      slug: band.slug,
      name: band.name,
      location: band.location,
      profile_picture_url: profile_picture_url(band),
      reviews_count: band.reviews.count,
      user_owned: band.user_owned?
    }
  end

  def self.full(band)
    {
      id: band.id,
      slug: band.slug,
      name: band.name,
      location: band.location,
      spotify_link: band.spotify_link,
      bandcamp_link: band.bandcamp_link,
      apple_music_link: band.apple_music_link,
      youtube_music_link: band.youtube_music_link,
      about: band.about,
      profile_picture_url: profile_picture_url(band),
      reviews_count: band.reviews.count,
      user_owned: band.user_owned?,
      owner: band.user ? { id: band.user.id, username: band.user.username } : nil,
      created_at: band.created_at,
      updated_at: band.updated_at
    }
  end

  def self.with_reviews(band)
    # Only include reviews from active (non-disabled) users
    active_reviews = QueryService.band_reviews_from_active_users(band)
    full(band).merge(
      reviews: active_reviews.map do |review|
        ReviewSerializer.with_author(review)
      end
    )
  end
end