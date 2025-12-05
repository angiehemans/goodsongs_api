# app/controllers/admin_controller.rb
class AdminController < ApplicationController
  before_action :require_admin

  # GET /admin/users
  def users
    users = User.all.order(created_at: :desc)
    json_response(users.map { |user| admin_user_data(user) })
  end

  # GET /admin/users/:id
  def user_detail
    user = User.find(params[:id])
    reviews = user.reviews.includes(:band).order(created_at: :desc)

    json_response({
      user: admin_user_data(user),
      reviews: reviews.map { |review| ReviewSerializer.full(review) }
    })
  end

  # PATCH /admin/users/:id/toggle-disabled
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

  # DELETE /admin/users/:id
  def destroy_user
    user = User.find(params[:id])

    # Prevent admin from deleting themselves
    if user.id == current_user.id
      return json_response({ error: 'You cannot delete your own account' }, :unprocessable_entity)
    end

    user.destroy!
    json_response({ message: 'User has been deleted' })
  end

  # GET /admin/bands
  def bands
    bands = Band.all.includes(:user, :reviews).order(:name)
    json_response(bands.map { |band| admin_band_data(band) })
  end

  # PATCH /admin/bands/:id/toggle-disabled
  def toggle_band_disabled
    band = Band.find(params[:id])
    band.update!(disabled: !band.disabled)

    json_response({
      message: band.disabled? ? 'Band has been disabled' : 'Band has been enabled',
      band: admin_band_data(band)
    })
  end

  # DELETE /admin/bands/:id
  def destroy_band
    band = Band.find(params[:id])

    # Nullify primary_band reference for any users who have this as their primary band
    User.where(primary_band_id: band.id).update_all(primary_band_id: nil)

    band.destroy!
    json_response({ message: 'Band has been deleted' })
  end

  # GET /admin/reviews
  def reviews
    reviews = Review.all.includes(:user, :band).order(created_at: :desc)
    json_response(reviews.map { |review| ReviewSerializer.full(review) })
  end

  # DELETE /admin/reviews/:id
  def destroy_review
    review = Review.find(params[:id])
    review.destroy!
    json_response({ message: 'Review has been deleted' })
  end

  private

  def admin_user_data(user)
    UserSerializer.public_profile(user).merge(
      admin: user.admin?,
      disabled: user.disabled?
    )
  end

  def admin_band_data(band)
    BandSerializer.full(band).merge(
      disabled: band.disabled?
    )
  end
end
