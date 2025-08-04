class ReviewsController < ApplicationController
  before_action :authenticate_request
  before_action :set_review, only: [:show, :update, :destroy]

  def index
    @reviews = Review.includes(:user, :band).order(created_at: :desc).limit(50)
    render json: @reviews.map { |review| ReviewSerializer.full(review) }
  end

  def show
    render json: ReviewSerializer.full(@review)
  end

  def create
    @band = find_or_create_band(review_params[:band_name])
    @review = current_user.reviews.build(review_params.merge(band: @band))

    if @review.save
      render json: ReviewSerializer.full(@review), status: :created
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
        render json: ReviewSerializer.full(@review)
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
    render json: @reviews.map { |review| ReviewSerializer.full(review) }
  end

  def user_reviews
    user = User.find(params[:user_id])
    @reviews = user.reviews.includes(:band).order(created_at: :desc)
    render json: @reviews.map { |review| ReviewSerializer.full(review) }
  end

  def current_user_reviews
    @reviews = current_user.reviews.includes(:band).order(created_at: :desc).limit(5)
    render json: @reviews.map { |review| ReviewSerializer.full(review) }
  end

  private

  def set_review
    @review = Review.find(params[:id])
  end

  def review_params
    params.require(:review).permit(:song_link, :band_name, :song_name, :artwork_url, 
                                  :review_text, :overall_rating, 
                                  liked_aspects: [])
  end

  def find_or_create_band(band_name)
    return nil if band_name.blank?
    Band.find_or_create_by(name: band_name.strip)
  end

end