class ReviewsController < ApplicationController
  before_action :authenticate_request
  before_action :set_review, only: [:show, :update, :destroy]

  def index
    @reviews = Review.includes(:user, :band).order(created_at: :desc).limit(50)
    render json: @reviews.map { |review| review_json(review) }
  end

  def show
    render json: review_json(@review)
  end

  def create
    @band = find_or_create_band(review_params[:band_name])
    @review = current_user.reviews.build(review_params.merge(band: @band))

    if @review.save
      render json: review_json(@review), status: :created
    else
      render json: { errors: @review.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def update
    if @review.user == current_user
      @band = find_or_create_band(review_params[:band_name]) if review_params[:band_name]
      update_params = review_params
      update_params[:band] = @band if @band

      if @review.update(update_params)
        render json: review_json(@review)
      else
        render json: { errors: @review.errors.full_messages }, status: :unprocessable_entity
      end
    else
      render json: { error: 'Unauthorized' }, status: :unauthorized
    end
  end

  def destroy
    if @review.user == current_user
      @review.destroy
      head :no_content
    else
      render json: { error: 'Unauthorized' }, status: :unauthorized
    end
  end

  def feed
    @reviews = Review.includes(:user, :band).order(created_at: :desc).limit(50)
    render json: @reviews.map { |review| review_json(review) }
  end

  def user_reviews
    user = User.find(params[:user_id])
    @reviews = user.reviews.includes(:band).order(created_at: :desc)
    render json: @reviews.map { |review| review_json(review) }
  end

  def current_user_reviews
    @reviews = current_user.reviews.includes(:band).order(created_at: :desc).limit(5)
    render json: @reviews.map { |review| review_json(review) }
  end

  private

  def set_review
    @review = Review.find(params[:id])
  end

  def review_params
    params.require(:review).permit(:song_link, :band_name, :song_name, :artwork_url, 
                                  :review_text, :overall_rating, liked_aspects: [])
  end

  def find_or_create_band(band_name)
    return nil if band_name.blank?
    Band.find_or_create_by(name: band_name.strip)
  end

  def review_json(review)
    {
      id: review.id,
      song_link: review.song_link,
      band_name: review.band_name,
      song_name: review.song_name,
      artwork_url: review.artwork_url,
      review_text: review.review_text,
      overall_rating: review.overall_rating,
      liked_aspects: review.liked_aspects_array,
      author: {
        id: review.user.id,
        username: review.user.username
      },
      band: {
        id: review.band.id,
        slug: review.band.slug,
        name: review.band.name,
        location: review.band.location,
        spotify_link: review.band.spotify_link,
        bandcamp_link: review.band.bandcamp_link,
        apple_music_link: review.band.apple_music_link,
        youtube_music_link: review.band.youtube_music_link,
        about: review.band.about,
        profile_picture_url: review.band.profile_picture.attached? ? url_for(review.band.profile_picture) : nil
      },
      created_at: review.created_at,
      updated_at: review.updated_at
    }
  end
end