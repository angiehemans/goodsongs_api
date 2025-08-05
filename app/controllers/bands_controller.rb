class BandsController < ApplicationController
  include ResourceController
  include Ownership

  before_action :authenticate_request, except: [:index, :show]
  before_action :set_band, only: [:show, :update, :destroy]
  before_action -> { ensure_ownership(@band) }, only: [:update, :destroy]

  def index
    bands = QueryService.bands_ordered_by_name
    json_response(bands.map { |band| BandSerializer.full(band) })
  end

  def show
    json_response(BandSerializer.with_reviews(@band))
  end

  def create
    @band = current_user.bands.build(band_params)

    if @band.save
      json_response(BandSerializer.full(@band), :created)
    else
      render_errors(@band)
    end
  end

  def update
    if @band.update(band_params)
      json_response(BandSerializer.full(@band))
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
    json_response(bands.map { |band| BandSerializer.full(band) })
  end

  def user_bands
    bands = QueryService.user_bands_with_reviews(current_user)
    json_response(bands.map { |band| BandSerializer.full(band) })
  end

  private

  def set_band
    @band = Band.includes(reviews: :user).find_by!(slug: params[:slug])
  end

  def band_params
    params.require(:band).permit(:name, :slug, :location, :spotify_link, :bandcamp_link, 
                                 :apple_music_link, :youtube_music_link, :about, :profile_picture)
  end

end