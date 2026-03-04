# frozen_string_literal: true

# MaxMind GeoLite2-Country Database Configuration
#
# Download the free GeoLite2-Country database from MaxMind:
# https://dev.maxmind.com/geoip/geoip2/geolite2/
#
# Place the GeoLite2-Country.mmdb file in db/geoip/
#
# The database should be updated monthly. Consider setting up
# a cron job or Heroku scheduler to download updates.

Rails.application.config.after_initialize do
  db_path = Rails.root.join('db', 'geoip', 'GeoLite2-Country.mmdb')

  unless File.exist?(db_path)
    Rails.logger.info(
      "[MaxMind] GeoLite2-Country.mmdb not found at #{db_path}. " \
      "Country detection will be disabled. Download from: " \
      "https://dev.maxmind.com/geoip/geoip2/geolite2/"
    )
  end
end
