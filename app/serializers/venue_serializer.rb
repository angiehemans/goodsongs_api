class VenueSerializer
  def self.full(venue)
    {
      id: venue.id,
      name: venue.name,
      address: venue.address,
      city: venue.city,
      region: venue.region,
      latitude: venue.latitude,
      longitude: venue.longitude,
      created_at: venue.created_at,
      updated_at: venue.updated_at
    }
  end

  def self.summary(venue)
    {
      id: venue.id,
      name: venue.name,
      address: venue.address,
      city: venue.city,
      region: venue.region
    }
  end
end
