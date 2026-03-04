# frozen_string_literal: true

class DeviceTypeParser
  VALID_TYPES = %w[desktop mobile tablet].freeze
  DEFAULT_TYPE = 'desktop'

  class << self
    def parse(user_agent)
      return DEFAULT_TYPE if user_agent.blank?

      client = DeviceDetector.new(user_agent)

      if client.device_type.nil?
        DEFAULT_TYPE
      elsif client.device_type == 'smartphone'
        'mobile'
      elsif VALID_TYPES.include?(client.device_type)
        client.device_type
      else
        DEFAULT_TYPE
      end
    rescue StandardError => e
      Rails.logger.warn("DeviceTypeParser error: #{e.message}")
      DEFAULT_TYPE
    end
  end
end
