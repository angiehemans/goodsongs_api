class VenuesController < ApplicationController
  include ResourceController

  before_action :authenticate_request, only: [:create]

  def index
    venues = Venue.order(:name)

    if params[:search].present?
      venues = venues.where('name ILIKE ?', "%#{params[:search]}%")
    end

    json_response(venues.map { |venue| VenueSerializer.full(venue) })
  end

  def show
    venue = Venue.find(params[:id])
    json_response(VenueSerializer.full(venue))
  end

  def create
    venue = Venue.new(venue_params)

    if venue.save
      json_response(VenueSerializer.full(venue), :created)
    else
      render_errors(venue)
    end
  end

  private

  def venue_params
    params.require(:venue).permit(:name, :address, :city, :region)
  end
end
