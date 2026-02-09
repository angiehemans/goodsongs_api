class DiscoverController < ApplicationController
  extend ImageUrlHelper

  skip_before_action :authenticate_request
  skip_before_action :require_onboarding_completed

  # GET /discover/bands
  # Params:
  #   - q: search query for band name (optional)
  #   - page, per_page: pagination
  def bands
    page = (params[:page] || 1).to_i
    per_page = (params[:per_page] || 20).to_i
    per_page = [per_page, 50].min
    query = params[:q]&.strip.presence

    base_scope = Band.where(disabled: false)

    if query.present?
      # Use trigram search for band names
      band_ids = base_scope
                   .where("name % ?", query)
                   .order(Arel.sql("similarity(name, #{Band.connection.quote(query)}) DESC"))
                   .offset((page - 1) * per_page)
                   .limit(per_page)
                   .pluck(:id)

      total_count = base_scope.where("name % ?", query).count
    else
      # Default: order by review count
      total_count = base_scope.count

      band_ids = base_scope
                   .left_joins(:reviews)
                   .group('bands.id')
                   .order(Arel.sql('COUNT(reviews.id) DESC, bands.name ASC'))
                   .offset((page - 1) * per_page)
                   .limit(per_page)
                   .pluck(:id)
    end

    paginated_bands = Band.where(id: band_ids)
                         .includes(:user, :reviews)
                         .index_by(&:id)
                         .values_at(*band_ids)
                         .compact

    json_response({
      bands: paginated_bands.map { |band| BandSerializer.full(band) },
      pagination: pagination_meta(page, per_page, total_count),
      query: query
    })
  end

  # GET /discover/users
  # Params:
  #   - q: search query for username (optional)
  #   - page, per_page: pagination
  def users
    page = (params[:page] || 1).to_i
    per_page = (params[:per_page] || 20).to_i
    per_page = [per_page, 50].min
    query = params[:q]&.strip.presence

    # Only show active fan users who have completed onboarding (not band accounts)
    base_scope = User.where(disabled: false, onboarding_completed: true, account_type: :fan)

    if query.present?
      # Search by username using trigram similarity
      users = base_scope
                .where("username % ?", query)
                .order(Arel.sql("similarity(username, #{User.connection.quote(query)}) DESC"))

      total_count = users.count
      paginated_users = users.offset((page - 1) * per_page).limit(per_page)
    else
      users = base_scope.order(created_at: :desc)
      total_count = users.count
      paginated_users = users.offset((page - 1) * per_page).limit(per_page)
    end

    json_response({
      users: paginated_users.map { |user| discover_user_data(user) },
      pagination: pagination_meta(page, per_page, total_count),
      query: query
    })
  end

  # GET /discover/reviews
  # Params:
  #   - q: search query for band name or song name (optional)
  #   - page, per_page: pagination
  def reviews
    page = (params[:page] || 1).to_i
    per_page = (params[:per_page] || 20).to_i
    per_page = [per_page, 50].min
    query = params[:q]&.strip.presence

    base_scope = Review.from_active_users.includes(:user, :band)

    if query.present?
      # Search by band_name or song_name using trigram similarity
      reviews = base_scope
                  .where("band_name % ? OR song_name % ?", query, query)
                  .order(Arel.sql("GREATEST(similarity(band_name, #{Review.connection.quote(query)}), similarity(song_name, #{Review.connection.quote(query)})) DESC"))

      total_count = reviews.count
      paginated_reviews = reviews.offset((page - 1) * per_page).limit(per_page)
    else
      reviews = base_scope.order(created_at: :desc)
      total_count = reviews.count
      paginated_reviews = reviews.offset((page - 1) * per_page).limit(per_page)
    end

    json_response({
      reviews: paginated_reviews.map { |review| ReviewSerializer.full(review, current_user: authenticated_user) },
      pagination: pagination_meta(page, per_page, total_count),
      query: query
    })
  end

  # GET /discover/events
  # Params:
  #   - q: search query for band name (optional)
  #   - page, per_page: pagination
  def events
    page = (params[:page] || 1).to_i
    per_page = (params[:per_page] || 20).to_i
    per_page = [per_page, 50].min
    query = params[:q]&.strip.presence

    base_scope = Event.active.upcoming.from_active_bands.includes(:venue, :band)

    if query.present?
      # Search by band name using trigram similarity via join
      events = base_scope
                 .joins(:band)
                 .where("bands.name % ?", query)
                 .order(Arel.sql("similarity(bands.name, #{Band.connection.quote(query)}) DESC"))

      total_count = events.count
      paginated_events = events.offset((page - 1) * per_page).limit(per_page)
    else
      events = base_scope
      total_count = events.count
      paginated_events = events.offset((page - 1) * per_page).limit(per_page)
    end

    json_response({
      events: paginated_events.map { |event| EventSerializer.full(event) },
      pagination: pagination_meta(page, per_page, total_count),
      query: query
    })
  end

  # GET /discover/search
  # Unified search across bands, users, reviews, and events
  # Params:
  #   - q: search query (required)
  #   - limit: max results per category (default: 5, max: 20)
  def search
    query = params[:q]&.strip.presence
    limit = [[params[:limit]&.to_i || 5, 20].min, 1].max

    if query.blank?
      return json_response({ error: 'Search query is required' }, :bad_request)
    end

    results = {}

    # Search bands
    band_ids = Band.where(disabled: false)
                   .where("name % ?", query)
                   .order(Arel.sql("similarity(name, #{Band.connection.quote(query)}) DESC"))
                   .limit(limit)
                   .pluck(:id)

    results[:bands] = Band.where(id: band_ids)
                          .includes(:user, :reviews)
                          .index_by(&:id)
                          .values_at(*band_ids)
                          .compact
                          .map { |band| BandSerializer.full(band) }

    # Search users
    results[:users] = User.where(disabled: false, onboarding_completed: true, account_type: :fan)
                          .where("username % ?", query)
                          .order(Arel.sql("similarity(username, #{User.connection.quote(query)}) DESC"))
                          .limit(limit)
                          .map { |user| discover_user_data(user) }

    # Search reviews
    results[:reviews] = Review.from_active_users
                              .includes(:user, :band)
                              .where("band_name % ? OR song_name % ?", query, query)
                              .order(Arel.sql("GREATEST(similarity(band_name, #{Review.connection.quote(query)}), similarity(song_name, #{Review.connection.quote(query)})) DESC"))
                              .limit(limit)
                              .map { |review| ReviewSerializer.full(review, current_user: authenticated_user) }

    # Search events by band name
    results[:events] = Event.active.upcoming.from_active_bands
                            .includes(:venue, :band)
                            .joins(:band)
                            .where("bands.name % ?", query)
                            .order(Arel.sql("similarity(bands.name, #{Band.connection.quote(query)}) DESC"))
                            .limit(limit)
                            .map { |event| EventSerializer.full(event) }

    json_response({
      results: results,
      query: query,
      counts: {
        bands: results[:bands].size,
        users: results[:users].size,
        reviews: results[:reviews].size,
        events: results[:events].size
      }
    })
  end

  private

  def pagination_meta(page, per_page, total_count)
    total_pages = (total_count.to_f / per_page).ceil
    {
      current_page: page,
      per_page: per_page,
      total_count: total_count,
      total_pages: total_pages,
      has_next_page: page < total_pages,
      has_previous_page: page > 1
    }
  end

  def discover_user_data(user)
    data = {
      id: user.id,
      username: user.username,
      display_name: user.display_name,
      account_type: user.account_type,
      about_me: user.about_me,
      profile_image_url: self.class.profile_image_url(user),
      location: user.location,
      reviews_count: user.reviews.count,
      bands_count: user.bands.count,
      followers_count: user.followers.count,
      following_count: user.following.count
    }

    # Include primary band for BAND accounts
    if user.band? && user.primary_band
      data[:primary_band] = BandSerializer.summary(user.primary_band)
    end

    data
  end
end
