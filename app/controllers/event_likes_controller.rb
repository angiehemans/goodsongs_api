class EventLikesController < ApplicationController
  before_action :authenticate_request
  before_action :set_event, only: [:create, :destroy]

  # POST /events/:id/like
  def create
    if current_user.likes_event?(@event)
      return json_response({ error: "You have already liked this event" }, :unprocessable_entity)
    end

    current_user.like_event(@event)

    # Notify the event creator
    Notification.notify_event_like(event: @event, liker: current_user)

    json_response({
      message: "Event liked successfully",
      liked: true,
      likes_count: @event.likes_count
    })
  end

  # DELETE /events/:id/like
  def destroy
    unless current_user.likes_event?(@event)
      return json_response({ error: "You have not liked this event" }, :unprocessable_entity)
    end

    current_user.unlike_event(@event)

    json_response({
      message: "Event unliked successfully",
      liked: false,
      likes_count: @event.likes_count
    })
  end

  # GET /events/liked
  def index
    page = (params[:page] || 1).to_i
    per_page = (params[:per_page] || 20).to_i
    per_page = [per_page, 50].min

    liked_events = current_user.liked_events
      .includes(:user, :venue, :band)
      .order('event_likes.created_at DESC')
      .offset((page - 1) * per_page)
      .limit(per_page)

    total_count = current_user.liked_events.count
    total_pages = (total_count.to_f / per_page).ceil

    json_response({
      events: liked_events.map { |event| EventSerializer.full(event, current_user: current_user) },
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

  def set_event
    @event = Event.find(params[:id])
  end
end
