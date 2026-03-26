class ThreadsPostService < SocialPostService
  BASE_URL = "https://graph.threads.net/v1.0".freeze

  def post(account, postable)
    payload = SharePayloadBuilder.new(postable).for_threads
    token = account.access_token
    user_id = account.platform_user_id

    # Step 1: Create container
    container_params = { text: payload[:text] }
    if payload[:image_url].present?
      container_params[:media_type] = "IMAGE"
      container_params[:image_url] = payload[:image_url]
    else
      container_params[:media_type] = "TEXT"
    end

    container_uri = URI("#{BASE_URL}/#{user_id}/threads")
    container_response = post_json(container_uri, container_params, token)
    container_result = handle_response(container_response)
    return unless container_result

    container_id = container_result["id"]

    # Step 2: Publish
    publish_uri = URI("#{BASE_URL}/#{user_id}/threads_publish")
    publish_response = post_json(publish_uri, { creation_id: container_id }, token)
    handle_response(publish_response)
  end
end
