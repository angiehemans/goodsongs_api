class ReviewSerializer
  include Rails.application.routes.url_helpers
  extend ImageUrlHelper

  def self.full(review, current_user: nil)
    mentions = review.mentions.loaded? ? review.mentions : review.mentions.includes(:user)
    {
      id: review.id,
      song_link: review.song_link,
      band_name: review.band_name,
      song_name: review.song_name,
      artwork_url: resolved_artwork_url(review),
      review_text: review.review_text,
      formatted_review_text: MentionService.format_content(review.review_text, mentions),
      mentions: serialize_mentions(mentions),
      liked_aspects: review.liked_aspects_array,
      genres: review.genres || [],
      track: review.track ? track_summary(review.track, current_user: current_user) : nil,
      band: BandSerializer.full(review.band, current_user: current_user),
      author: author_data(review.user),
      likes_count: review.likes_count,
      liked_by_current_user: review.liked_by?(current_user),
      comments_count: review.comments_count,
      created_at: review.created_at,
      updated_at: review.updated_at
    }
  end

  def self.with_author(review, current_user: nil)
    mentions = review.mentions.loaded? ? review.mentions : review.mentions.includes(:user)
    {
      id: review.id,
      song_link: review.song_link,
      band_name: review.band_name,
      song_name: review.song_name,
      artwork_url: resolved_artwork_url(review),
      review_text: review.review_text,
      formatted_review_text: MentionService.format_content(review.review_text, mentions),
      mentions: serialize_mentions(mentions),
      liked_aspects: review.liked_aspects_array,
      genres: review.genres || [],
      track: review.track ? track_summary(review.track, current_user: current_user) : nil,
      author: author_data(review.user),
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

  def self.track_summary(track, current_user: nil)
    {
      id: track.id,
      name: track.name,
      album: track.album ? { id: track.album.id, name: track.album.name } : nil,
      source: track.source,
      artwork_url: track.resolved_artwork_url,
      streaming_links: track.streaming_links || {},
      preferred_track_link: preferred_track_link_for(track, current_user),
      songlink_url: track.songlink_url,
      songlink_search_url: track.songlink_search_url
    }
  end

  def self.preferred_track_link_for(track, user)
    return nil unless user&.preferred_streaming_platform.present?

    links = track.streaming_links || {}
    links[user.preferred_streaming_platform]
  end

  def self.author_data(user)
    data = {
      id: user.id,
      username: user.username,
      display_name: user.display_name,
      role: user.role,
      plan: user.plan ? { key: user.plan.key, name: user.plan.name } : nil,
      profile_image_url: author_avatar_url(user)
    }
    data[:band_slug] = user.primary_band.slug if user.band? && user.primary_band
    data
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

  # Resolve artwork: review's own URL first, then fall back to track artwork
  def self.resolved_artwork_url(review)
    return review.artwork_url if review.artwork_url.present?

    review.track&.resolved_artwork_url
  end
end