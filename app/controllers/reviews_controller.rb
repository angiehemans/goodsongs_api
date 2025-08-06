class ReviewsController < ApplicationController
  include ResourceController
  include Ownership

  before_action :authenticate_request
  before_action :set_review, only: [:show, :update, :destroy]
  before_action -> { ensure_ownership(@review) }, only: [:update, :destroy]

  def index
    reviews = QueryService.recent_reviews
    json_response(reviews.map { |review| ReviewSerializer.full(review) })
  end

  def show
    json_response(ReviewSerializer.full(@review))
  end

  def create
    @band = find_or_create_band(review_params[:band_name])
    @review = current_user.reviews.build(review_params.merge(band: @band))

    if @review.save
      json_response(ReviewSerializer.full(@review), :created)
    else
      render_errors(@review)
    end
  end

  def update
    @band = find_or_create_band(review_params[:band_name]) if review_params[:band_name]
    update_params = review_params
    update_params[:band] = @band if @band

    if @review.update(update_params)
      json_response(ReviewSerializer.full(@review))
    else
      render_errors(@review)
    end
  end

  def destroy
    @review.destroy
    head :no_content
  end

  def feed
    reviews = QueryService.recent_reviews
    json_response(reviews.map { |review| ReviewSerializer.full(review) })
  end

  def user_reviews
    user = User.find(params[:user_id])
    reviews = QueryService.user_reviews_with_associations(user)
    json_response(reviews.map { |review| ReviewSerializer.full(review) })
  end

  def current_user_reviews
    reviews = QueryService.user_reviews_with_associations(current_user).limit(5)
    json_response(reviews.map { |review| ReviewSerializer.full(review) })
  end

  private

  def set_review
    @review = Review.find(params[:id])
  end

  def review_params
    params.require(:review).permit(:song_link, :band_name, :song_name, :artwork_url, 
                                  :review_text, 
                                  liked_aspects: [])
  end

  def find_or_create_band(band_name)
    return nil if band_name.blank?
    Band.find_or_create_by(name: band_name.strip)
  end

end