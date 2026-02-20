class ReviewCommentLikesController < ApplicationController
  before_action :authenticate_request
  before_action :set_comment

  # POST /comments/:comment_id/like
  def create
    if current_user.likes_comment?(@comment)
      return json_response({ error: "You have already liked this comment" }, :unprocessable_entity)
    end

    current_user.like_comment(@comment)

    # Notify the comment author
    Notification.notify_comment_like(comment: @comment, liker: current_user)

    json_response({
      message: "Comment liked successfully",
      liked: true,
      likes_count: @comment.likes_count
    })
  end

  # DELETE /comments/:comment_id/like
  def destroy
    unless current_user.likes_comment?(@comment)
      return json_response({ error: "You have not liked this comment" }, :unprocessable_entity)
    end

    current_user.unlike_comment(@comment)

    json_response({
      message: "Comment unliked successfully",
      liked: false,
      likes_count: @comment.likes_count
    })
  end

  private

  def set_comment
    @comment = ReviewComment.find(params[:comment_id])
  end
end
