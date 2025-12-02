# app/controllers/concerns/adminable.rb
module Adminable
  extend ActiveSupport::Concern

  private

  def require_admin
    unless current_user&.admin?
      render json: { error: 'Admin access required' }, status: :forbidden
    end
  end

  def authorize_modification(resource)
    unless current_user&.can_modify?(resource)
      render json: { error: 'You are not authorized to modify this resource' }, status: :forbidden
    end
  end
end
