# app/controllers/admin_controller.rb
class AdminController < ApplicationController
  before_action :require_admin

  def users
    users = User.all.order(created_at: :desc)
    json_response(users.map { |user| admin_user_data(user) })
  end

  def user_detail
    user = User.find(params[:id])
    reviews = user.reviews.includes(:band).order(created_at: :desc)

    json_response({
      user: admin_user_data(user),
      reviews: reviews.map { |review| ReviewSerializer.full(review) }
    })
  end

  def toggle_disabled
    user = User.find(params[:id])

    # Prevent admin from disabling themselves
    if user.id == current_user.id
      return json_response({ error: 'You cannot disable your own account' }, :unprocessable_entity)
    end

    user.update!(disabled: !user.disabled)

    json_response({
      message: user.disabled? ? 'User has been disabled' : 'User has been enabled',
      user: admin_user_data(user)
    })
  end

  private

  def admin_user_data(user)
    UserSerializer.public_profile(user).merge(
      admin: user.admin?,
      disabled: user.disabled?
    )
  end
end
