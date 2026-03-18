class EventCommentLikesController < ApplicationController
  before_action :authenticate_request
  before_action :set_comment

  # POST /event_comments/:comment_id/like
  def create
    if current_user.likes_event_comment?(@comment)
      return json_response({ error: "You have already liked this comment" }, :unprocessable_entity)
    end

    current_user.like_event_comment(@comment)

    # Notify the comment author
    Notification.notify_event_comment_like(comment: @comment, liker: current_user)

    json_response({
      message: "Comment liked successfully",
      liked: true,
      likes_count: @comment.likes_count
    })
  end

  # DELETE /event_comments/:comment_id/like
  def destroy
    unless current_user.likes_event_comment?(@comment)
      return json_response({ error: "You have not liked this comment" }, :unprocessable_entity)
    end

    current_user.unlike_event_comment(@comment)

    json_response({
      message: "Comment unliked successfully",
      liked: false,
      likes_count: @comment.likes_count
    })
  end

  private

  def set_comment
    @comment = EventComment.find(params[:comment_id])
  end
end
