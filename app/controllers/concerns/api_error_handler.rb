# frozen_string_literal: true

# Comprehensive error handling for API endpoints
# Following the standardized error format from PRD
module ApiErrorHandler
  extend ActiveSupport::Concern

  # Custom error classes
  class RateLimitedError < StandardError
    attr_reader :retry_after

    def initialize(message = 'Too many requests', retry_after: nil)
      @retry_after = retry_after
      super(message)
    end
  end

  class ForbiddenError < StandardError; end

  included do
    rescue_from StandardError, with: :handle_internal_error
    rescue_from ActiveRecord::RecordNotFound, with: :handle_not_found
    rescue_from ActiveRecord::RecordInvalid, with: :handle_validation_error
    rescue_from ActionController::ParameterMissing, with: :handle_parameter_missing
    rescue_from ApiErrorHandler::RateLimitedError, with: :handle_rate_limited
    rescue_from ApiErrorHandler::ForbiddenError, with: :handle_forbidden
    rescue_from ExceptionHandler::AuthenticationError, with: :handle_unauthorized
    rescue_from ExceptionHandler::MissingToken, with: :handle_unauthorized
    rescue_from ExceptionHandler::InvalidToken, with: :handle_unauthorized
  end

  private

  def handle_unauthorized(_exception)
    render_api_error(
      code: 'unauthorized',
      message: 'Missing or invalid authentication token',
      status: :unauthorized
    )
  end

  def handle_forbidden(_exception)
    render_api_error(
      code: 'forbidden',
      message: 'You do not have permission to perform this action',
      status: :forbidden
    )
  end

  def handle_not_found(exception)
    # Extract resource type from exception message
    resource = exception.model || 'Resource'

    render_api_error(
      code: 'not_found',
      message: "#{resource} not found",
      status: :not_found
    )
  end

  def handle_validation_error(exception)
    details = exception.record.errors.map do |error|
      { field: error.attribute.to_s, message: error.message }
    end

    render_api_error(
      code: 'validation_failed',
      message: 'Validation failed',
      status: :unprocessable_entity,
      details: details
    )
  end

  def handle_parameter_missing(exception)
    render_api_error(
      code: 'validation_failed',
      message: "Missing required parameter: #{exception.param}",
      status: :unprocessable_entity
    )
  end

  def handle_rate_limited(exception)
    details = {}
    details[:retry_after] = exception.retry_after if exception.retry_after

    render_api_error(
      code: 'rate_limited',
      message: exception.message,
      status: :too_many_requests,
      details: details.presence
    )
  end

  def handle_internal_error(exception)
    # Log the full error for debugging
    Rails.logger.error("Internal error: #{exception.class} - #{exception.message}")
    Rails.logger.error(exception.backtrace&.first(10)&.join("\n"))

    # Don't expose internal details in production
    message = Rails.env.production? ? 'An unexpected error occurred' : exception.message

    render_api_error(
      code: 'internal_error',
      message: message,
      status: :internal_server_error
    )
  end

  def render_api_error(code:, message:, status:, details: nil)
    response = {
      error: {
        code: code,
        message: message
      }
    }
    response[:error][:details] = details if details.present?

    render json: response, status: status
  end
end
