class PostSerializer
  include Rails.application.routes.url_helpers
  extend ImageUrlHelper

  def self.summary(post, current_user: nil)
    {
      id: post.id,
      title: post.title,
      slug: post.slug,
      excerpt: post.excerpt,
      featured: post.featured,
      status: post.status,
      publish_date: post.publish_date,
      featured_image_url: post.featured_image_url,
      tags: post.tags || [],
      categories: post.categories || [],
      authors: post.effective_authors,
      author: author_data(post.user),
      song: song_data(post, current_user: current_user),
      likes_count: post.likes_count,
      liked_by_current_user: post.liked_by?(current_user),
      comments_count: post.comments_count,
      created_at: post.created_at,
      updated_at: post.updated_at
    }
  end

  def self.full(post, current_user: nil)
    {
      id: post.id,
      title: post.title,
      slug: post.slug,
      excerpt: post.excerpt,
      body: post.body,
      featured: post.featured,
      status: post.status,
      publish_date: post.publish_date,
      featured_image_url: post.featured_image_url,
      tags: post.tags || [],
      categories: post.categories || [],
      authors: post.effective_authors,
      author: author_data(post.user),
      song: song_data(post, current_user: current_user),
      likes_count: post.likes_count,
      liked_by_current_user: post.liked_by?(current_user),
      comments_count: post.comments_count,
      can_edit: current_user && post.user_id == current_user.id,
      created_at: post.created_at,
      updated_at: post.updated_at
    }
  end

  def self.for_feed(post, current_user: nil)
    {
      id: post.id,
      title: post.title,
      slug: post.slug,
      excerpt: post.excerpt,
      featured: post.featured,
      publish_date: post.publish_date,
      featured_image_url: post.featured_image_url,
      tags: post.tags || [],
      authors: post.effective_authors,
      author: author_data(post.user),
      song: song_data(post, current_user: current_user)
    }
  end

  def self.for_management(post)
    {
      id: post.id,
      title: post.title,
      slug: post.slug,
      status: post.status,
      featured: post.featured,
      authors: post.effective_authors,
      publish_date: post.publish_date,
      created_at: post.created_at,
      updated_at: post.updated_at
    }
  end

  def self.author_data(user)
    {
      id: user.id,
      username: user.username,
      display_name: user.display_name,
      profile_image_url: profile_image_url(user),
      allow_anonymous_comments: user.allow_anonymous_comments
    }
  end

  def self.song_data(post, current_user: nil)
    return nil unless post.has_song?

    data = {
      song_name: post.song_name,
      band_name: post.band_name,
      album_name: post.album_name,
      artwork_url: post.artwork_url,
      song_link: post.song_link
    }

    # Include streaming links if track exists
    if post.track
      data[:streaming_links] = post.track.streaming_links || {}
      data[:preferred_link] = preferred_track_link_for(post.track, current_user)
      data[:songlink_url] = post.track.songlink_url
      data[:songlink_search_url] = post.track.songlink_search_url

      # Include band streaming links
      if post.track.band
        data[:band_links] = band_links(post.track.band, current_user)
      end
    end

    data
  end

  def self.band_links(band, current_user)
    {
      spotify: band.spotify_link,
      apple_music: band.apple_music_link,
      youtube_music: band.youtube_music_link,
      bandcamp: band.bandcamp_link,
      soundcloud: band.soundcloud_link,
      preferred_link: BandSerializer.preferred_link_for(band, current_user)
    }
  end

  def self.preferred_track_link_for(track, user)
    return nil unless user&.preferred_streaming_platform.present?

    links = track.streaming_links || {}
    links[user.preferred_streaming_platform]
  end
end
