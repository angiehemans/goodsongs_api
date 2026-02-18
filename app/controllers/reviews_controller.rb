class ReviewsController < ApplicationController
  include ResourceController
  include Ownership

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
    page = (params[:page] || 1).to_i
    per_page = (params[:per_page] || 20).to_i
    per_page = [per_page, 50].min # Cap at 50 per page

    reviews = QueryService.following_feed(current_user, page: page, per_page: per_page)
    total_count = QueryService.following_feed_count(current_user)
    total_pages = (total_count.to_f / per_page).ceil

    json_response({
      reviews: reviews.map { |review| ReviewSerializer.full(review, current_user: current_user) },
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

  def user_reviews
    user = User.find(params[:user_id])
    reviews = QueryService.user_reviews_with_associations(user)
    json_response(reviews.map { |review| ReviewSerializer.full(review, current_user: current_user) })
  end

  def current_user_reviews
    reviews = QueryService.user_reviews_with_associations(current_user).limit(5)
    json_response(reviews.map { |review| ReviewSerializer.full(review, current_user: current_user) })
  end

  private

  def set_review
    @review = Review.find(params[:id])
  end

  def review_params
    params.require(:review).permit(:song_link, :band_name, :song_name, :artwork_url,
                                  :review_text,
                                  liked_aspects: [],
                                  genres: [])
  end

  def find_or_create_track(band, song_name)
    return nil if band.blank? || song_name.blank?

    song = song_name.strip

    # 1. Exact case-insensitive match on band's tracks
    track = band.tracks.where("LOWER(name) = LOWER(?)", song).first
    return track if track

    # 2. Fuzzy match with >0.6 similarity threshold
    similar_track = band.tracks
      .where("name % ?", song)
      .where("similarity(name, ?) > 0.6", song)
      .order(Arel.sql("similarity(name, #{Track.connection.quote(song)}) DESC"))
      .first
    return similar_track if similar_track

    # 3. Create new user-submitted track
    Track.create!(
      name: song,
      band: band,
      source: :user_submitted,
      submitted_by: current_user
    )
  end

  def band_lastfm_artist_name
    params.dig(:review, :band_lastfm_artist_name)
  end

  def band_musicbrainz_id
    params.dig(:review, :band_musicbrainz_id)
  end

  def find_or_create_band(band_name)
    return nil if band_name.blank?

    name = band_name.strip
    mbid = band_musicbrainz_id

    # 1. Exact MBID match (most reliable identifier)
    if mbid.present?
      band = Band.find_by(musicbrainz_id: mbid)
      return backfill_band(band) if band
    end

    # 2. Case-insensitive exact name match
    band = Band.where("LOWER(name) = LOWER(?)", name).first
    return backfill_band(band) if band

    # 3. Handle "The" prefix variations — "The Beatles" ↔ "Beatles"
    normalized = name.sub(/\Athe\s+/i, '')
    with_the = "The #{normalized}"
    band = Band.where("LOWER(name) = LOWER(?) OR LOWER(name) = LOWER(?)", normalized, with_the).first
    return backfill_band(band) if band

    # 4. Check band aliases
    band_alias = BandAlias.where("LOWER(name) = LOWER(?)", name).first
    return backfill_band(band_alias.band) if band_alias

    # 5. Create new band
    band = Band.new(name: name)
    backfill_band(band)
  end

  def backfill_band(band)
    if band_lastfm_artist_name.present? && band.lastfm_artist_name.blank?
      band.lastfm_artist_name = band_lastfm_artist_name
    end

    if band_musicbrainz_id.present? && band.musicbrainz_id.blank?
      band.musicbrainz_id = band_musicbrainz_id
    end

    band.save! if band.new_record? || band.changed?
    band
  end

end