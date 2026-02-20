class ReviewCommentsController < ApplicationController
  before_action :authenticate_request
  before_action :set_review
  before_action :set_comment, only: [:update, :destroy]
  before_action :ensure_comment_owner, only: [:update, :destroy]

  # GET /reviews/:review_id/comments
  def index
    page = (params[:page] || 1).to_i
    per_page = (params[:per_page] || 20).to_i
    per_page = [per_page, 50].min

    comments = @review.review_comments.includes(:user).chronological
    total_count = comments.count
    paginated_comments = comments.offset((page - 1) * per_page).limit(per_page)

    json_response({
      comments: paginated_comments.map { |comment| serialize_comment(comment) },
      pagination: {
        current_page: page,
        per_page: per_page,
        total_count: total_count,
        total_pages: (total_count.to_f / per_page).ceil,
        has_next_page: page < (total_count.to_f / per_page).ceil,
        has_previous_page: page > 1
      }
    })
  end

  # POST /reviews/:review_id/comments
  def create
    # Validate mentions before creating
    mention_service = MentionService.new(comment_params[:body], mentioner: current_user)
    validation = mention_service.validate
    unless validation[:valid]
      return json_response({ error: validation[:error] }, :unprocessable_entity)
    end

    @comment = @review.review_comments.build(comment_params.merge(user: current_user))

    if @comment.save
      # Notify the review author
      Notification.notify_review_comment(review: @review, commenter: current_user, comment: @comment)

      json_response({
        message: "Comment added successfully",
        comment: serialize_comment(@comment),
        comments_count: @review.comments_count
      }, :created)
    else
      json_response({ errors: @comment.errors.full_messages }, :unprocessable_entity)
    end
  end

  # PATCH /reviews/:review_id/comments/:id
  def update
    # Validate mentions before updating
    mention_service = MentionService.new(comment_params[:body], mentioner: current_user)
    validation = mention_service.validate
    unless validation[:valid]
      return json_response({ error: validation[:error] }, :unprocessable_entity)
    end

    if @comment.update(comment_params)
      json_response({
        message: "Comment updated successfully",
        comment: serialize_comment(@comment)
      })
    else
      json_response({ errors: @comment.errors.full_messages }, :unprocessable_entity)
    end
  end

  # DELETE /reviews/:review_id/comments/:id
  def destroy
    @comment.destroy
    json_response({
      message: "Comment deleted successfully",
      comments_count: @review.comments_count
    })
  end

  private

  def set_review
    @review = Review.find(params[:review_id])
  end

  def set_comment
    @comment = @review.review_comments.find(params[:id])
  end

  def ensure_comment_owner
    unless current_user.id == @comment.user_id || current_user.admin?
      json_response({ error: "You are not authorized to modify this comment" }, :forbidden)
    end
  end

  def comment_params
    params.require(:comment).permit(:body)
  end

  def serialize_comment(comment)
    mentions = comment.mentions.includes(:user)
    {
      id: comment.id,
      body: comment.body,
      formatted_body: MentionService.format_content(comment.body, mentions),
      mentions: mentions.map do |mention|
        {
          user_id: mention.user_id,
          username: mention.user.username,
          display_name: mention.user.display_name
        }
      end,
      author: {
        id: comment.user.id,
        username: comment.user.username,
        display_name: comment.user.display_name,
        profile_image_url: UserSerializer.profile_image_url(comment.user)
      },
      likes_count: comment.likes_count,
      liked_by_current_user: comment.liked_by?(current_user),
      created_at: comment.created_at,
      updated_at: comment.updated_at
    }
  end
end
