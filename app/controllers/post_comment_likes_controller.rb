class PostCommentLikesController < ApplicationController
  before_action :authenticate_request
  before_action :set_comment

  # POST /post_comments/:comment_id/like
  def create
    if current_user.likes_post_comment?(@comment)
      return json_response({ error: "You have already liked this comment" }, :unprocessable_entity)
    end

    current_user.like_post_comment(@comment)

    # Notify the comment author (only for non-anonymous comments)
    unless @comment.anonymous?
      Notification.notify_post_comment_like(comment: @comment, liker: current_user)
    end

    json_response({
      message: "Comment liked successfully",
      liked: true,
      likes_count: @comment.likes_count
    })
  end

  # DELETE /post_comments/:comment_id/like
  def destroy
    unless current_user.likes_post_comment?(@comment)
      return json_response({ error: "You have not liked this comment" }, :unprocessable_entity)
    end

    current_user.unlike_post_comment(@comment)

    json_response({
      message: "Comment unliked successfully",
      liked: false,
      likes_count: @comment.likes_count
    })
  end

  private

  def set_comment
    @comment = PostComment.find(params[:comment_id])
  end
end
