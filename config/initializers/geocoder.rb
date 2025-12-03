# config/initializers/geocoder.rb
Geocoder.configure(
  # Use Nominatim (OpenStreetMap) - free but has rate limits
  lookup: :nominatim,

  # Set a proper user agent as required by Nominatim ToS
  http_headers: { "User-Agent" => "GoodSongs App (contact@goodsongs.app)" },

  # Timeout settings
  timeout: 5,

  # Cache results to reduce API calls
  cache: Rails.cache,
  cache_options: {
    expiration: 1.day
  },

  # Use HTTPS
  use_https: true,

  # Units for distance calculations
  units: :mi
)
