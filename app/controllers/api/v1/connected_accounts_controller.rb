class Api::V1::ConnectedAccountsController < ApplicationController
  def index
    accounts = current_user.connected_accounts
    json_response(accounts.map { |a| ConnectedAccountSerializer.full(a) })
  end

  def update
    account = current_user.connected_accounts.find_by!(platform: params[:platform])
    account.update!(update_params)
    json_response(ConnectedAccountSerializer.full(account))
  end

  def destroy
    account = current_user.connected_accounts.find_by!(platform: params[:platform])
    account.destroy!
    json_response({ message: "Disconnected #{params[:platform]}" })
  end

  private

  def update_params
    params.permit(:auto_post_recommendations, :auto_post_band_posts, :auto_post_events)
  end
end
