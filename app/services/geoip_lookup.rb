# frozen_string_literal: true

class GeoipLookup
  class << self
    def country(ip_address)
      return nil if ip_address.blank?
      return nil if private_ip?(ip_address)
      return nil unless database_available?

      begin
        result = reader.get(ip_address)
        return nil unless result

        result.dig('country', 'iso_code')
      rescue MaxMind::DB::AddressNotFoundError
        nil
      rescue StandardError => e
        Rails.logger.warn("GeoipLookup error for #{ip_address}: #{e.message}")
        nil
      end
    end

    def database_available?
      reader.present?
    rescue StandardError
      false
    end

    private

    def reader
      @reader ||= begin
        db_path = Rails.root.join('db', 'geoip', 'GeoLite2-Country.mmdb')
        return nil unless File.exist?(db_path)

        MaxMind::DB.new(db_path.to_s, mode: MaxMind::DB::MODE_MEMORY)
      end
    end

    def private_ip?(ip_address)
      ip = IPAddr.new(ip_address)
      ip.private? || ip.loopback? || ip.link_local?
    rescue IPAddr::InvalidAddressError
      true
    end
  end
end
