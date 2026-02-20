class ReviewSerializer
  include Rails.application.routes.url_helpers
  extend ImageUrlHelper

  def self.full(review, current_user: nil)
    mentions = review.mentions.includes(:user)
    {
      id: review.id,
      song_link: review.song_link,
      band_name: review.band_name,
      song_name: review.song_name,
      artwork_url: review.artwork_url,
      review_text: review.review_text,
      formatted_review_text: MentionService.format_content(review.review_text, mentions),
      mentions: serialize_mentions(mentions),
      liked_aspects: review.liked_aspects_array,
      genres: review.genres || [],
      track: review.track ? track_summary(review.track) : nil,
      band: BandSerializer.full(review.band),
      author: {
        id: review.user.id,
        username: review.user.username,
        profile_image_url: profile_image_url(review.user)
      },
      likes_count: review.likes_count,
      liked_by_current_user: review.liked_by?(current_user),
      comments_count: review.comments_count,
      created_at: review.created_at,
      updated_at: review.updated_at
    }
  end

  def self.with_author(review, current_user: nil)
    mentions = review.mentions.includes(:user)
    {
      id: review.id,
      song_link: review.song_link,
      song_name: review.song_name,
      artwork_url: review.artwork_url,
      review_text: review.review_text,
      formatted_review_text: MentionService.format_content(review.review_text, mentions),
      mentions: serialize_mentions(mentions),
      liked_aspects: review.liked_aspects_array,
      genres: review.genres || [],
      track: review.track ? track_summary(review.track) : nil,
      author: {
        id: review.user.id,
        username: review.user.username,
        profile_image_url: profile_image_url(review.user)
      },
      likes_count: review.likes_count,
      liked_by_current_user: review.liked_by?(current_user),
      comments_count: review.comments_count,
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

  def self.track_summary(track)
    {
      id: track.id,
      name: track.name,
      album: track.album ? { id: track.album.id, name: track.album.name } : nil,
      source: track.source
    }
  end

  def self.serialize_mentions(mentions)
    mentions.map do |mention|
      {
        user_id: mention.user_id,
        username: mention.user.username,
        display_name: mention.user.display_name
      }
    end
  end
end