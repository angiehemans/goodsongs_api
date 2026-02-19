# frozen_string_literal: true

# Background job for sending push notifications
class SendPushNotificationJob < ApplicationJob
  queue_as :default

  # Retry on network errors
  retry_on Net::OpenTimeout, Net::ReadTimeout, OpenSSL::SSL::SSLError,
           Errno::ECONNRESET, Errno::ECONNREFUSED, SocketError,
           wait: :polynomially_longer, attempts: 3

  def perform(user_id, title:, body:, data: {})
    user = User.find_by(id: user_id)
    return unless user

    result = PushNotificationService.send_to_user(
      user,
      title: title,
      body: body,
      data: data
    )

    Rails.logger.info(
      "SendPushNotificationJob: user_id=#{user_id} sent=#{result[:sent]} failed=#{result[:failed]}"
    )
  end
end
