class ReviewSerializer
  include Rails.application.routes.url_helpers
  extend ImageUrlHelper

  def self.full(review)
    {
      id: review.id,
      song_link: review.song_link,
      band_name: review.band_name,
      song_name: review.song_name,
      artwork_url: review.artwork_url,
      review_text: review.review_text,
      liked_aspects: review.liked_aspects_array,
      band: BandSerializer.full(review.band),
      created_at: review.created_at,
      updated_at: review.updated_at
    }
  end

  def self.with_author(review)
    {
      id: review.id,
      song_link: review.song_link,
      song_name: review.song_name,
      artwork_url: review.artwork_url,
      review_text: review.review_text,
      liked_aspects: review.liked_aspects_array,
      author: {
        id: review.user.id,
        username: review.user.username,
        profile_image_url: profile_image_url(review.user)
      },
      created_at: review.created_at,
      updated_at: review.updated_at
    }
  end

  def self.summary(review)
    {
      id: review.id,
      song_name: review.song_name,
      band_name: review.band_name,
      created_at: review.created_at
    }
  end
end