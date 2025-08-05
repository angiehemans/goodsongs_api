module Ownership
  extend ActiveSupport::Concern

  private

  def ensure_ownership(resource, user = current_user, message = 'You can only modify resources you own')
    unless resource.user == user
      render_unauthorized(message)
      false
    else
      true
    end
  end

  def ensure_current_user_ownership(resource, message = 'You can only modify your own resources')
    ensure_ownership(resource, current_user, message)
  end

  def check_resource_ownership(resource, user = current_user)
    resource.user == user
  end
end