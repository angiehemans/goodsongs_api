class BandsController < ApplicationController
  before_action :authenticate_request, except: [:index, :show]
  before_action :set_band, only: [:show, :update, :destroy]
  before_action :check_band_ownership, only: [:update, :destroy]

  def index
    @bands = Band.includes(:reviews, :user).order(:name)
    render json: @bands.map { |band| BandSerializer.full(band) }
  end

  def show
    render json: BandSerializer.with_reviews(@band)
  end

  def create
    @band = current_user.bands.build(band_params)

    if @band.save
      render json: BandSerializer.full(@band), status: :created
    else
      render json: { errors: @band.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def update
    if @band.update(band_params)
      render json: BandSerializer.full(@band)
    else
      render json: { errors: @band.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def destroy
    @band.destroy
    head :no_content
  end

  def my_bands
    @bands = current_user.bands.includes(:reviews).order(:name)
    render json: @bands.map { |band| BandSerializer.full(band) }
  end

  def user_bands
    bands = current_user.bands.includes(:reviews).order(created_at: :desc)
    render json: bands.map { |band| BandSerializer.full(band) }
  end

  private

  def set_band
    @band = Band.includes(reviews: :user).find_by!(slug: params[:slug])
  end

  def check_band_ownership
    unless @band.user == current_user
      render json: { error: 'You can only edit bands you created' }, status: :unauthorized
    end
  end

  def band_params
    params.require(:band).permit(:name, :slug, :location, :spotify_link, :bandcamp_link, 
                                 :apple_music_link, :youtube_music_link, :about, :profile_picture)
  end

end