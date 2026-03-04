class BandsController < ApplicationController
  include ResourceController
  include Ownership

  before_action :authenticate_request, except: [:index, :show]
  before_action :set_band, only: [:show, :update, :destroy]
  before_action -> { ensure_ownership(@band) }, only: [:update, :destroy]

  def index
    bands = QueryService.bands_ordered_by_name
    json_response(bands.map { |band| BandSerializer.full(band, current_user: authenticated_user) })
  end

  def show
    # Don't show disabled bands publicly
    if @band.disabled?
      return render json: { error: 'Band not found' }, status: :not_found
    end
    json_response(BandSerializer.with_reviews(@band, current_user: authenticated_user))
  end

  def create
    @band = current_user.bands.build(band_params)

    if @band.save
      json_response(BandSerializer.full(@band, current_user: current_user), :created)
    else
      render_errors(@band)
    end
  end

  def update
    if @band.update(band_params)
      json_response(BandSerializer.full(@band, current_user: current_user))
    else
      render_errors(@band)
    end
  end

  def destroy
    @band.destroy
    head :no_content
  end

  def my_bands
    bands = QueryService.user_bands_with_reviews(current_user)
    json_response(bands.map { |band| BandSerializer.full(band, current_user: current_user) })
  end

  def user_bands
    bands = QueryService.user_bands_with_reviews(current_user)
    json_response(bands.map { |band| BandSerializer.full(band, current_user: current_user) })
  end

  private

  def set_band
    @band = Band.includes(reviews: :user).find_by!(slug: params[:slug])
  end

  def band_params
    params.require(:band).permit(
      :name, :slug, :city, :region, :about, :profile_picture,
      # Streaming links
      :spotify_link, :bandcamp_link, :bandcamp_embed, :apple_music_link, :youtube_music_link,
      # Social links
      :instagram_url, :threads_url, :bluesky_url, :twitter_url,
      :tumblr_url, :tiktok_url, :facebook_url, :youtube_url
    )
  end

end