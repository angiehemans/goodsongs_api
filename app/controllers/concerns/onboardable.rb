# app/controllers/concerns/onboardable.rb
module Onboardable
  extend ActiveSupport::Concern

  included do
    before_action :require_onboarding_completed
  end

  private

  def require_onboarding_completed
    return unless current_user
    return if current_user.onboarding_completed?

    render json: {
      error: 'Onboarding required',
      message: 'Please complete onboarding by selecting your account type',
      onboarding_completed: false
    }, status: :forbidden
  end

  def skip_onboarding_check
    # Override in controllers to skip onboarding requirement for specific actions
  end
end
