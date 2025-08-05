module ResourceController
  extend ActiveSupport::Concern

  private

  def render_errors(resource, status: :unprocessable_entity)
    render json: { errors: resource.errors.full_messages }, status: status
  end

  def render_unauthorized(message = 'Unauthorized')
    render json: { error: message }, status: :unauthorized
  end

  def render_resource(resource, serializer_class, status: :ok)
    render json: serializer_class.full(resource), status: status
  end

  def render_collection(collection, serializer_class, method: :full)
    render json: collection.map { |item| serializer_class.public_send(method, item) }
  end

  def render_success(data = {}, status: :ok)
    render json: data, status: status
  end

  def render_not_found(message = 'Resource not found')
    render json: { error: message }, status: :not_found
  end
end