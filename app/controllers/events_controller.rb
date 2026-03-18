class EventsController < ApplicationController
  include ResourceController
  include Paginatable

  before_action :authenticate_request, except: [:index, :band_index, :show, :user_events]
  before_action :set_band, only: [:band_index, :band_create]
  before_action :set_event, only: [:show, :update, :destroy]
  before_action :ensure_band_ownership, only: [:band_create]
  before_action :ensure_event_ownership, only: [:update, :destroy]

  # GET /events
  def index
    events = Event.active.upcoming.visible.includes(:venue, :band, :user)
    total_count = events.count
    events = paginate(events)
    json_response({
      events: events.map { |event| EventSerializer.full(event, current_user: current_user) },
      pagination: pagination_meta(page_param, per_page_param, total_count)
    })
  end

  # GET /bands/:band_slug/events
  def band_index
    events = @band.events.active.upcoming.includes(:venue)
    total_count = events.count
    events = paginate(events)
    json_response({
      events: events.map { |event| EventSerializer.full(event, current_user: current_user) },
      pagination: pagination_meta(page_param, per_page_param, total_count)
    })
  end

  # GET /users/:user_id/events
  def user_events
    user = User.find(params[:user_id])
    events = user.events.active.upcoming.includes(:venue, :band)
    total_count = events.count
    events = paginate(events)
    json_response({
      events: events.map { |event| EventSerializer.full(event, current_user: current_user) },
      pagination: pagination_meta(page_param, per_page_param, total_count)
    })
  end

  # GET /events/:id
  def show
    json_response(EventSerializer.full(@event, current_user: current_user))
  end

  # POST /events
  def create
    require_ability!(:manage_events) and return if performed?

    venue = find_or_create_venue
    return if venue.nil?

    @event = current_user.events.build(event_params.except(:venue_id, :venue_attributes))
    @event.venue = venue

    # Optionally associate with a band (must be owned by current user)
    if params[:event][:band_id].present?
      band = current_user.bands.find_by(id: params[:event][:band_id])
      unless band
        return render json: { errors: ['Band not found or not owned by you'] }, status: :unprocessable_entity
      end
      @event.band = band
    end

    if @event.save
      json_response(EventSerializer.full(@event, current_user: current_user), :created)
    else
      render_errors(@event)
    end
  end

  # POST /bands/:band_slug/events
  def band_create
    require_ability!(:manage_events) and return if performed?

    venue = find_or_create_venue
    return if venue.nil?

    @event = @band.events.build(event_params.except(:venue_id, :venue_attributes))
    @event.venue = venue
    @event.user = current_user

    if @event.save
      json_response(EventSerializer.full(@event, current_user: current_user), :created)
    else
      render_errors(@event)
    end
  end

  # PATCH /events/:id
  def update
    if params[:event][:venue_id].present?
      @event.venue = Venue.find(params[:event][:venue_id])
    elsif params[:event][:venue_attributes].present?
      venue = find_or_create_venue
      return if venue.nil?
      @event.venue = venue
    end

    if @event.update(event_params.except(:venue_id, :venue_attributes))
      json_response(EventSerializer.full(@event, current_user: current_user))
    else
      render_errors(@event)
    end
  end

  # DELETE /events/:id
  def destroy
    @event.destroy
    head :no_content
  end

  private

  def set_band
    @band = Band.find_by!(slug: params[:band_slug])
  end

  def set_event
    @event = Event.includes(:venue, :band, :user).find(params[:id])
  end

  def ensure_band_ownership
    unless @band.user == current_user
      render_unauthorized('You can only create events for bands you own')
    end
  end

  def ensure_event_ownership
    unless @event.user == current_user
      render_unauthorized('You can only modify your own events')
    end
  end

  def event_params
    params.require(:event).permit(
      :name, :description, :event_date, :ticket_link,
      :image_url, :image, :price, :age_restriction, :venue_id,
      venue_attributes: [:name, :address, :city, :region]
    )
  end

  def find_or_create_venue
    if params[:event][:venue_id].present?
      Venue.find(params[:event][:venue_id])
    elsif params[:event][:venue_attributes].present?
      venue_attrs = params[:event][:venue_attributes].permit(:name, :address, :city, :region)
      venue = Venue.find_or_initialize_by(
        name: venue_attrs[:name],
        address: venue_attrs[:address]
      )
      venue.assign_attributes(venue_attrs)

      if venue.save
        venue
      else
        render json: { errors: venue.errors.full_messages }, status: :unprocessable_entity
        nil
      end
    else
      render json: { errors: ['Venue is required'] }, status: :unprocessable_entity
      nil
    end
  end
end
