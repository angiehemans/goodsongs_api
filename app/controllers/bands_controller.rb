class BandsController < ApplicationController
  before_action :authenticate_request, except: [:index, :show]
  before_action :set_band, only: [:show, :update, :destroy]
  before_action :check_band_ownership, only: [:update, :destroy]

  def index
    @bands = Band.all.order(:name)
    render json: @bands.map { |band| band_json(band) }
  end

  def show
    render json: band_json_with_reviews(@band)
  end

  def create
    @band = current_user.bands.build(band_params)

    if @band.save
      render json: band_json(@band), status: :created
    else
      render json: { errors: @band.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def update
    if @band.update(band_params)
      render json: band_json(@band)
    else
      render json: { errors: @band.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def destroy
    @band.destroy
    head :no_content
  end

  def my_bands
    @bands = current_user.bands.order(:name)
    render json: @bands.map { |band| band_json(band) }
  end

  def user_bands
    bands = current_user.bands.includes(:reviews).order(created_at: :desc)
    render json: bands.map { |band| band_json(band) }
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

  def band_json(band)
    {
      id: band.id,
      slug: band.slug,
      name: band.name,
      location: band.location,
      spotify_link: band.spotify_link,
      bandcamp_link: band.bandcamp_link,
      apple_music_link: band.apple_music_link,
      youtube_music_link: band.youtube_music_link,
      about: band.about,
      profile_picture_url: band.profile_picture.attached? ? url_for(band.profile_picture) : nil,
      reviews_count: band.reviews.count,
      user_owned: band.user_owned?,
      owner: band.user ? { id: band.user.id, username: band.user.username } : nil,
      created_at: band.created_at,
      updated_at: band.updated_at
    }
  end

  def band_json_with_reviews(band)
    {
      id: band.id,
      slug: band.slug,
      name: band.name,
      location: band.location,
      spotify_link: band.spotify_link,
      bandcamp_link: band.bandcamp_link,
      apple_music_link: band.apple_music_link,
      youtube_music_link: band.youtube_music_link,
      about: band.about,
      profile_picture_url: band.profile_picture.attached? ? url_for(band.profile_picture) : nil,
      reviews_count: band.reviews.count,
      user_owned: band.user_owned?,
      owner: band.user ? { id: band.user.id, username: band.user.username } : nil,
      reviews: band.reviews.order(created_at: :desc).map do |review|
        {
          id: review.id,
          song_link: review.song_link,
          song_name: review.song_name,
          artwork_url: review.artwork_url,
          review_text: review.review_text,
          overall_rating: review.overall_rating,
          liked_aspects: review.liked_aspects_array,
          author: {
            id: review.user.id,
            username: review.user.username
          },
          created_at: review.created_at,
          updated_at: review.updated_at
        }
      end,
      created_at: band.created_at,
      updated_at: band.updated_at
    }
  end
end