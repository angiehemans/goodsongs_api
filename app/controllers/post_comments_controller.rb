class PostCommentsController < ApplicationController
  skip_before_action :authenticate_request, only: [:index, :create]
  before_action :authenticate_request_optional, only: [:index, :create]
  before_action :authenticate_request, only: [:update, :destroy, :claim]
  before_action :set_post, except: [:claim]
  before_action :set_comment, only: [:update, :destroy]
  before_action :ensure_comment_owner, only: [:update, :destroy]

  # GET /posts/:post_id/comments
  def index
    page = (params[:page] || 1).to_i
    per_page = (params[:per_page] || 20).to_i
    per_page = [per_page, 50].min

    comments = @post.post_comments.includes(:user).chronological
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

  # POST /posts/:post_id/comments
  def create
    if current_user
      create_authenticated_comment
    else
      create_anonymous_comment
    end
  end

  # PATCH /posts/:post_id/comments/:id
  def update
    # Anonymous comments cannot be edited (they have no user)
    if @comment.anonymous?
      return json_response({ error: "Anonymous comments cannot be edited" }, :forbidden)
    end

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

  # DELETE /posts/:post_id/comments/:id
  def destroy
    @comment.destroy
    json_response({
      message: "Comment deleted successfully",
      comments_count: @post.comments_count
    })
  end

  # POST /post_comments/claim
  def claim
    claim_token = params[:claim_token]
    return json_response({ error: "Claim token is required" }, :bad_request) if claim_token.blank?

    comment = PostComment.find_by(claim_token: claim_token)
    return json_response({ error: "Invalid or expired claim token" }, :not_found) unless comment

    unless comment.anonymous?
      return json_response({ error: "Comment has already been claimed" }, :unprocessable_entity)
    end

    if comment.claim!(current_user)
      json_response({
        message: "Comment claimed successfully",
        comment: serialize_comment(comment)
      })
    else
      json_response({ error: "Failed to claim comment" }, :unprocessable_entity)
    end
  end

  private

  def create_authenticated_comment
    # Validate mentions before creating
    mention_service = MentionService.new(comment_params[:body], mentioner: current_user)
    validation = mention_service.validate
    unless validation[:valid]
      return json_response({ error: validation[:error] }, :unprocessable_entity)
    end

    @comment = @post.post_comments.build(comment_params.merge(user: current_user))

    if @comment.save
      # Notify the post author
      Notification.notify_post_comment(post: @post, commenter: current_user, comment: @comment)

      json_response({
        message: "Comment added successfully",
        comment: serialize_comment(@comment),
        comments_count: @post.comments_count
      }, :created)
    else
      json_response({ errors: @comment.errors.full_messages }, :unprocessable_entity)
    end
  end

  def create_anonymous_comment
    # Check if post author allows anonymous comments
    unless @post.user.allow_anonymous_comments?
      return json_response({ error: "Anonymous comments are not allowed on this post" }, :forbidden)
    end

    @comment = @post.post_comments.build(anonymous_comment_params)

    if @comment.save
      # Notify post author (no actor for anonymous)
      Notification.notify_anonymous_post_comment(post: @post, comment: @comment)

      json_response({
        message: "Comment added successfully",
        comment: serialize_comment(@comment),
        claim_token: @comment.claim_token,
        comments_count: @post.comments_count
      }, :created)
    else
      json_response({ errors: @comment.errors.full_messages }, :unprocessable_entity)
    end
  end

  def set_post
    @post = Post.find(params[:post_id])
  end

  def set_comment
    @comment = @post.post_comments.find(params[:id])
  end

  def ensure_comment_owner
    # For anonymous comments, only admin can delete
    if @comment.anonymous?
      unless current_user.admin?
        return json_response({ error: "You are not authorized to modify this comment" }, :forbidden)
      end
    else
      unless current_user.id == @comment.user_id || current_user.admin?
        return json_response({ error: "You are not authorized to modify this comment" }, :forbidden)
      end
    end
  end

  def comment_params
    params.require(:comment).permit(:body)
  end

  def anonymous_comment_params
    params.require(:comment).permit(:body, :guest_name, :guest_email)
  end

  def serialize_comment(comment)
    result = {
      id: comment.id,
      body: comment.body,
      anonymous: comment.anonymous?,
      likes_count: comment.likes_count,
      liked_by_current_user: comment.liked_by?(current_user),
      created_at: comment.created_at,
      updated_at: comment.updated_at
    }

    if comment.anonymous?
      result[:guest_name] = comment.guest_name
      # guest_email is never exposed
    else
      mentions = comment.mentions.includes(:user)
      result.merge!(
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
        }
      )
    end

    result
  end
end
