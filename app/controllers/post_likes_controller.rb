class PostLikesController < ApplicationController
  before_action :authenticate_request
  before_action :set_post, only: [:create, :destroy]

  # POST /posts/:id/like
  def create
    if current_user.likes_post?(@post)
      return json_response({ error: "You have already liked this post" }, :unprocessable_entity)
    end

    current_user.like_post(@post)

    # Notify the post author (skip if liking own post)
    if @post.user_id != current_user.id
      Notification.notify_post_like(post: @post, liker: current_user)
    end

    json_response({
      message: "Post liked successfully",
      liked: true,
      likes_count: @post.likes_count
    })
  end

  # DELETE /posts/:id/like
  def destroy
    unless current_user.likes_post?(@post)
      return json_response({ error: "You have not liked this post" }, :unprocessable_entity)
    end

    current_user.unlike_post(@post)

    json_response({
      message: "Post unliked successfully",
      liked: false,
      likes_count: @post.likes_count
    })
  end

  # GET /posts/liked
  def index
    page = (params[:page] || 1).to_i
    per_page = (params[:per_page] || 20).to_i
    per_page = [per_page, 50].min

    liked_posts = current_user.liked_posts
      .includes(:user)
      .order('post_likes.created_at DESC')
      .offset((page - 1) * per_page)
      .limit(per_page)

    total_count = current_user.liked_posts.count
    total_pages = (total_count.to_f / per_page).ceil

    json_response({
      posts: liked_posts.map { |post| PostSerializer.summary(post, current_user: current_user) },
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

  def set_post
    @post = Post.find(params[:id])
  end
end
