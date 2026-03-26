class InstagramPostService < SocialPostService
  BASE_URL = "https://graph.instagram.com/v21.0".freeze

  def post(account, postable)
    payload = SharePayloadBuilder.new(postable).for_instagram

    # Instagram requires an image — skip if none available
    return unless payload[:image_url].present?

    token = account.access_token
    user_id = account.platform_user_id

    # Step 1: Create media container
    container_params = {
      image_url: payload[:image_url],
      caption: payload[:caption]
    }

    container_uri = URI("#{BASE_URL}/#{user_id}/media")
    container_response = post_json(container_uri, container_params, token)
    container_result = handle_response(container_response)
    return unless container_result

    container_id = container_result["id"]

    # Step 2: Publish
    publish_uri = URI("#{BASE_URL}/#{user_id}/media_publish")
    publish_response = post_json(publish_uri, { creation_id: container_id }, token)
    handle_response(publish_response)
  end
end
