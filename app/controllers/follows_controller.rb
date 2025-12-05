class FollowsController < ApplicationController
  before_action :authenticate_request
  before_action :set_user, only: [:create, :destroy]

  # POST /users/:user_id/follow
  def create
    if current_user.following?(@user)
      return json_response({ error: "You are already following this user" }, :unprocessable_entity)
    end

    current_user.follow(@user)
    json_response({
      message: "Successfully followed #{@user.display_name}",
      following: true,
      followers_count: @user.followers.count,
      following_count: @user.following.count
    })
  end

  # DELETE /users/:user_id/follow
  def destroy
    unless current_user.following?(@user)
      return json_response({ error: "You are not following this user" }, :unprocessable_entity)
    end

    current_user.unfollow(@user)
    json_response({
      message: "Successfully unfollowed #{@user.display_name}",
      following: false,
      followers_count: @user.followers.count,
      following_count: @user.following.count
    })
  end

  # GET /following
  def following
    users = current_user.following.where(disabled: false)
    json_response(users.map { |user| user_summary(user) })
  end

  # GET /followers
  def followers
    users = current_user.followers.where(disabled: false)
    json_response(users.map { |user| user_summary(user) })
  end

  # GET /users/:user_id/following
  def user_following
    user = find_active_user(params[:user_id])
    users = user.following.where(disabled: false)
    json_response(users.map { |u| user_summary(u) })
  end

  # GET /users/:user_id/followers
  def user_followers
    user = find_active_user(params[:user_id])
    users = user.followers.where(disabled: false)
    json_response(users.map { |u| user_summary(u) })
  end

  private

  def set_user
    @user = User.find(params[:user_id])
    if @user.disabled?
      raise ActiveRecord::RecordNotFound
    end
  end

  def find_active_user(user_id)
    user = User.find(user_id)
    raise ActiveRecord::RecordNotFound if user.disabled?
    user
  end

  def user_summary(user)
    {
      id: user.id,
      username: user.username,
      display_name: user.display_name,
      account_type: user.account_type,
      profile_image_url: ImageUrlHelper.profile_image_url(user),
      location: user.location,
      following: current_user.following?(user)
    }
  end
end
