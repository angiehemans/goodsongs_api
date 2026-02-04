class DiscoverController < ApplicationController
  extend ImageUrlHelper

  skip_before_action :authenticate_request
  skip_before_action :require_onboarding_completed

  # GET /discover/bands
  def bands
    page = (params[:page] || 1).to_i
    per_page = (params[:per_page] || 20).to_i
    per_page = [per_page, 50].min

    total_count = Band.where(disabled: false).count

    band_ids = Band.where(disabled: false)
                   .left_joins(:reviews)
                   .group('bands.id')
                   .order(Arel.sql('COUNT(reviews.id) DESC, bands.name ASC'))
                   .offset((page - 1) * per_page)
                   .limit(per_page)
                   .pluck(:id)

    paginated_bands = Band.where(id: band_ids)
                         .includes(:user, :reviews)
                         .index_by(&:id)
                         .values_at(*band_ids)
                         .compact

    json_response({
      bands: paginated_bands.map { |band| BandSerializer.full(band) },
      pagination: pagination_meta(page, per_page, total_count)
    })
  end

  # GET /discover/users
  def users
    page = (params[:page] || 1).to_i
    per_page = (params[:per_page] || 20).to_i
    per_page = [per_page, 50].min

    # Only show active fan users who have completed onboarding (not band accounts)
    users = User.where(disabled: false, onboarding_completed: true, account_type: :fan).order(created_at: :desc)
    total_count = users.count
    paginated_users = users.offset((page - 1) * per_page).limit(per_page)

    json_response({
      users: paginated_users.map { |user| discover_user_data(user) },
      pagination: pagination_meta(page, per_page, total_count)
    })
  end

  # GET /discover/reviews
  def reviews
    page = (params[:page] || 1).to_i
    per_page = (params[:per_page] || 20).to_i
    per_page = [per_page, 50].min

    reviews = Review.from_active_users.includes(:user, :band).order(created_at: :desc)
    total_count = reviews.count
    paginated_reviews = reviews.offset((page - 1) * per_page).limit(per_page)

    json_response({
      reviews: paginated_reviews.map { |review| ReviewSerializer.full(review) },
      pagination: pagination_meta(page, per_page, total_count)
    })
  end

  # GET /discover/events
  def events
    page = (params[:page] || 1).to_i
    per_page = (params[:per_page] || 20).to_i
    per_page = [per_page, 50].min

    events = Event.active.upcoming.from_active_bands.includes(:venue, :band)
    total_count = events.count
    paginated_events = events.offset((page - 1) * per_page).limit(per_page)

    json_response({
      events: paginated_events.map { |event| EventSerializer.full(event) },
      pagination: pagination_meta(page, per_page, total_count)
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
