# frozen_string_literal: true

# Service for sending push notifications via Firebase Cloud Messaging (FCM) V1 API
class PushNotificationService
  class << self
    # Send notification to a specific user
    def send_to_user(user, title:, body:, data: {})
      tokens = user.device_tokens.active.pluck(:token)
      return { sent: 0, failed: 0 } if tokens.empty?

      send_to_tokens(tokens, title: title, body: body, data: data)
    end

    # Send notification to multiple tokens
    def send_to_tokens(tokens, title:, body:, data: {})
      return { sent: 0, failed: 0 } if tokens.empty?

      fcm = build_fcm_client
      return { sent: 0, failed: 0, error: 'FCM not configured' } unless fcm

      sent = 0
      failed = 0
      invalid_tokens = []

      tokens.each do |token|
        response = send_to_token(fcm, token, title: title, body: body, data: data)

        if response[:success]
          sent += 1
        else
          failed += 1
          invalid_tokens << token if response[:invalid_token]
        end
      end

      # Remove invalid tokens from database
      DeviceToken.where(token: invalid_tokens).destroy_all if invalid_tokens.any?

      { sent: sent, failed: failed }
    end

    private

    def build_fcm_client
      project_id = ENV['FIREBASE_PROJECT_ID']
      return nil unless project_id.present?

      credentials = if ENV['FIREBASE_SERVICE_ACCOUNT_JSON_BASE64'].present?
                      # Base64-encoded JSON (most reliable for production)
                      decoded = Base64.decode64(ENV['FIREBASE_SERVICE_ACCOUNT_JSON_BASE64'])
                      StringIO.new(decoded)
                    elsif ENV['FIREBASE_SERVICE_ACCOUNT_JSON'].present?
                      # Raw JSON from environment variable
                      StringIO.new(ENV['FIREBASE_SERVICE_ACCOUNT_JSON'])
                    else
                      # Use file path (for development)
                      service_account_path = Rails.root.join('config', 'firebase-service-account.json')
                      return nil unless File.exist?(service_account_path)

                      service_account_path.to_s
                    end

      # FCM.new(json_key_path, project_name, http_options = {})
      FCM.new(credentials, project_id, {})
    rescue StandardError => e
      Rails.logger.error("PushNotificationService: Failed to initialize FCM - #{e.message}")
      nil
    end

    def send_to_token(fcm, token, title:, body:, data:)
      message = build_message(token, title: title, body: body, data: data)
      response = fcm.send_v1(message)

      if response[:status_code] == 200
        { success: true }
      else
        handle_error_response(response, token)
      end
    rescue StandardError => e
      Rails.logger.error("PushNotificationService: Send failed for token #{token[0..10]}... - #{e.message}")
      { success: false, error: e.message }
    end

    def build_message(token, title:, body:, data:)
      {
        token: token,
        notification: {
          title: title,
          body: body
        },
        data: data.transform_values(&:to_s),
        # Android-specific options
        android: {
          priority: 'high',
          notification: {
            sound: 'default',
            channel_id: 'goodsongs_notifications'
          }
        },
        # iOS-specific options (APNs)
        apns: {
          payload: {
            aps: {
              sound: 'default',
              badge: 1
            }
          }
        }
      }
    end

    def handle_error_response(response, token)
      status_code = response[:status_code]
      error_code = response.dig(:body, 'error', 'code')
      error_status = response.dig(:body, 'error', 'status')

      # Token is invalid or unregistered
      invalid_token = status_code == 404 ||
                      error_code == 404 ||
                      error_status == 'NOT_FOUND' ||
                      error_status == 'UNREGISTERED'

      if invalid_token
        Rails.logger.info("PushNotificationService: Removing invalid token #{token[0..10]}...")
      else
        Rails.logger.warn("PushNotificationService: Failed to send to #{token[0..10]}... - #{response[:body]}")
      end

      { success: false, invalid_token: invalid_token }
    end
  end
end
