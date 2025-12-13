class EventsController < ApplicationController
  include ResourceController

  before_action :authenticate_request, except: [:index, :show]
  before_action :set_band, only: [:index, :create]
  before_action :set_event, only: [:show, :update, :destroy]
  before_action :ensure_band_ownership, only: [:create]
  before_action :ensure_event_ownership, only: [:update, :destroy]

  # GET /bands/:band_slug/events
  def index
    events = @band.events.active.upcoming.includes(:venue)
    json_response(events.map { |event| EventSerializer.full(event) })
  end

  # GET /events/:id
  def show
    json_response(EventSerializer.full(@event))
  end

  # POST /bands/:band_slug/events
  def create
    venue = find_or_create_venue
    return if venue.nil?

    @event = @band.events.build(event_params.except(:venue_id, :venue_attributes))
    @event.venue = venue

    if @event.save
      json_response(EventSerializer.full(@event), :created)
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
      json_response(EventSerializer.full(@event))
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
    @event = Event.includes(:venue, :band).find(params[:id])
  end

  def ensure_band_ownership
    unless @band.user == current_user
      render_unauthorized('You can only create events for bands you own')
    end
  end

  def ensure_event_ownership
    unless @event.band.user == current_user
      render_unauthorized('You can only modify events for bands you own')
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
