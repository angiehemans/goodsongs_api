class ReviewsController < ApplicationController
  include ResourceController
  include Ownership
  include TrackFinder
  include Paginatable

  before_action :authenticate_request, except: [:show]
  before_action :authenticate_request_optional, only: [:show]
  before_action :set_review, only: [:show, :update, :destroy]
  before_action -> { ensure_ownership(@review) }, only: [:update, :destroy]

  def index
    reviews = QueryService.recent_reviews
    json_response(reviews.map { |review| ReviewSerializer.full(review, current_user: current_user) })
  end

  def show
    json_response(ReviewSerializer.full(@review, current_user: current_user))
  end

  def create
    # Validate mentions before creating
    if review_params[:review_text].present?
      mention_service = MentionService.new(review_params[:review_text], mentioner: current_user)
      validation = mention_service.validate
      unless validation[:valid]
        return json_response({ error: validation[:error] }, :unprocessable_entity)
      end
    end

    @band = find_or_create_band(review_params[:band_name])
    @track = find_or_create_track(@band, review_params[:song_name])
    @review = current_user.reviews.build(review_params.merge(band: @band, track: @track))

    if @review.save
      # Notify band owner if the band has one
      if @band&.user
        Notification.notify_new_review(band_owner: @band.user, review: @review)
      end

      json_response(ReviewSerializer.full(@review, current_user: current_user), :created)
    else
      render_errors(@review)
    end
  end

  def update
    # Validate mentions before updating
    if review_params[:review_text].present?
      mention_service = MentionService.new(review_params[:review_text], mentioner: current_user)
      validation = mention_service.validate
      unless validation[:valid]
        return json_response({ error: validation[:error] }, :unprocessable_entity)
      end
    end

    @band = find_or_create_band(review_params[:band_name]) if review_params[:band_name]
    update_params = review_params
    update_params[:band] = @band if @band

    if @review.update(update_params)
      json_response(ReviewSerializer.full(@review, current_user: current_user))
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
    json_response(reviews.map { |review| ReviewSerializer.full(review, current_user: current_user) })
  end

  # GET /feed/following
  def following_feed
    page = page_param
    per_page = per_page_param(default: 20, max: 50)

    items = QueryService.unified_following_feed(current_user, page: page, per_page: per_page)
    total_count = QueryService.unified_following_feed_count(current_user)

    json_response({
      feed_items: serialize_feed_items(items),
      pagination: pagination_meta(page, per_page, total_count)
    })
  end

  def user_reviews
    user = User.find(params[:user_id])
    reviews = QueryService.user_reviews_with_associations(user)
    total_count = reviews.count
    reviews = paginate(reviews)
    json_response({
      reviews: reviews.map { |review| ReviewSerializer.full(review, current_user: current_user) },
      pagination: pagination_meta(page_param, per_page_param, total_count)
    })
  end

  def current_user_reviews
    reviews = QueryService.user_reviews_with_associations(current_user).limit(5)
    json_response(reviews.map { |review| ReviewSerializer.full(review, current_user: current_user) })
  end

  private

  def serialize_feed_items(items)
    items.map do |item|
      case item[:type]
      when 'review'
        { type: 'review', data: ReviewSerializer.full(item[:record], current_user: current_user) }
      when 'post'
        { type: 'post', data: PostSerializer.for_feed(item[:record], current_user: current_user) }
      when 'event'
        { type: 'event', data: EventSerializer.for_feed(item[:record], current_user: current_user) }
      end
    end
  end

  def set_review
    @review = Review.find(params[:id])
  end

  def review_params
    params.require(:review).permit(:song_link, :band_name, :song_name, :artwork_url,
                                  :review_text,
                                  liked_aspects: [],
                                  genres: [])
  end

  # TrackFinder overrides for review params
  def band_lastfm_artist_name
    params.dig(:review, :band_lastfm_artist_name)
  end

  def band_musicbrainz_id
    params.dig(:review, :band_musicbrainz_id)
  end
end