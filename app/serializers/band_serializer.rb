class BandSerializer
  include Rails.application.routes.url_helpers

  def self.summary(band)
    {
      id: band.id,
      slug: band.slug,
      name: band.name,
      location: band.location,
      profile_picture_url: band.profile_picture.attached? ? 
        Rails.application.routes.url_helpers.url_for(band.profile_picture) : nil,
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
      profile_picture_url: band.profile_picture.attached? ? 
        Rails.application.routes.url_helpers.url_for(band.profile_picture) : nil,
      reviews_count: band.reviews.count,
      user_owned: band.user_owned?,
      owner: band.user ? { id: band.user.id, username: band.user.username } : nil,
      created_at: band.created_at,
      updated_at: band.updated_at
    }
  end

  def self.with_reviews(band)
    full(band).merge(
      reviews: band.reviews.order(created_at: :desc).map do |review|
        ReviewSerializer.with_author(review)
      end
    )
  end
end