class EventSerializer
  extend ImageUrlHelper

  def self.full(event)
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
      band: BandSerializer.summary(event.band),
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

  # Returns uploaded image if present, otherwise falls back to image_url field
  def self.event_image_url(event)
    if event.image.attached?
      attachment_url(event.image)
    else
      event.image_url
    end
  end
end
