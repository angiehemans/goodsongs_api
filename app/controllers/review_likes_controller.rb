class ReviewLikesController < ApplicationController
  before_action :authenticate_request
  before_action :set_review, only: [:create, :destroy]

  # POST /reviews/:id/like
  def create
    if current_user.likes_review?(@review)
      return json_response({ error: "You have already liked this review" }, :unprocessable_entity)
    end

    current_user.like_review(@review)

    # Notify the review author
    Notification.notify_review_like(review: @review, liker: current_user)

    json_response({
      message: "Review liked successfully",
      liked: true,
      likes_count: @review.likes_count
    })
  end

  # DELETE /reviews/:id/like
  def destroy
    unless current_user.likes_review?(@review)
      return json_response({ error: "You have not liked this review" }, :unprocessable_entity)
    end

    current_user.unlike_review(@review)

    json_response({
      message: "Review unliked successfully",
      liked: false,
      likes_count: @review.likes_count
    })
  end

  # GET /reviews/liked
  def index
    page = (params[:page] || 1).to_i
    per_page = (params[:per_page] || 20).to_i
    per_page = [per_page, 50].min

    liked_reviews = current_user.liked_reviews
      .includes(:user, :band)
      .order('review_likes.created_at DESC')
      .offset((page - 1) * per_page)
      .limit(per_page)

    total_count = current_user.liked_reviews.count
    total_pages = (total_count.to_f / per_page).ceil

    json_response({
      reviews: liked_reviews.map { |review| ReviewSerializer.full(review, current_user: current_user) },
      pagination: {
        current_page: page,
        per_page: per_page,
        total_count: total_count,
        total_pages: total_pages,
        has_next_page: page < total_pages,
        has_previous_page: page > 1
      }
    })
  end

  private

  def set_review
    @review = Review.find(params[:id])
  end
end
