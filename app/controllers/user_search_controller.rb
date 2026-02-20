class UserSearchController < ApplicationController
  before_action :authenticate_request

  # GET /users/search?q=john
  # For mention autocomplete when typing @
  def index
    query = params[:q].to_s.strip.downcase
    return json_response({ users: [] }) if query.length < 2

    users = User.where(disabled: false)
                .where.not(username: nil)
                .where('LOWER(username) LIKE ?', "#{query}%")
                .where.not(id: current_user.id)
                .limit(10)

    json_response({
      users: users.map do |user|
        {
          id: user.id,
          username: user.username,
          display_name: user.display_name,
          profile_image_url: UserSerializer.profile_image_url(user)
        }
      end
    })
  end
end
