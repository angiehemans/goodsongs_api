class EventSerializer
  extend ImageUrlHelper

  def self.full(event, current_user: nil)
    {
      id: event.id,
      name: event.name,
      description: event.description,
      event_date: event.event_date,
      ticket_link: event.ticket_link,
      image_url: event_image_url(event),
      price: event.price,
      age_restriction: event.age_restriction,
      venue: VenueSerializer.full(event.venue),
      band: event.band ? BandSerializer.summary(event.band) : nil,
      user_id: event.user_id,
      likes_count: event.likes_count,
      liked_by_current_user: event.liked_by?(current_user),
      comments_count: event.comments_count,
      created_at: event.created_at,
      updated_at: event.updated_at
    }
  end

  def self.for_feed(event, current_user: nil)
    {
      id: event.id,
      name: event.name,
      description: event.description,
      event_date: event.event_date,
      ticket_link: event.ticket_link,
      image_url: event_image_url(event),
      price: event.price,
      venue: VenueSerializer.summary(event.venue),
      band: event.band ? BandSerializer.summary(event.band) : nil,
      author: author_data(event.user),
      likes_count: event.likes_count,
      liked_by_current_user: event.liked_by?(current_user),
      comments_count: event.comments_count,
      created_at: event.created_at,
      updated_at: event.updated_at
    }
  end

  def self.summary(event)
    {
      id: event.id,
      name: event.name,
      event_date: event.event_date,
      image_url: event_image_url(event),
      venue: VenueSerializer.summary(event.venue),
      band_id: event.band_id
    }
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

  # Returns uploaded image if present, otherwise falls back to image_url field
  def self.event_image_url(event)
    if event.image.attached?
      attachment_url(event.image)
    else
      event.image_url
    end
  end
end
