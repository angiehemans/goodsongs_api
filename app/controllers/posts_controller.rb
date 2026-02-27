class PostsController < ApplicationController
  include ResourceController
  include Ownership
  include TrackFinder

  before_action :authenticate_request, except: [:user_posts, :show]
  before_action :authenticate_request_optional, only: [:user_posts, :show]
  before_action :set_post, only: [:show_by_id, :update, :destroy]
  before_action -> { ensure_ownership(@post) }, only: [:show_by_id, :update, :destroy]

  # GET /blogs/:username - User's blog profile with posts
  def user_posts
    user = User.find_by!(username: params[:username])

    # Don't show disabled user profiles
    if user.disabled?
      return render_not_found('Blog not found')
    end

    # Pagination
    page = (params[:page] || 1).to_i
    per_page = (params[:per_page] || 10).to_i
    per_page = [per_page, 50].min

    posts = user.posts.visible.newest_featured_first

    # Filter by tag if provided
    posts = posts.with_tag(params[:tag]) if params[:tag].present?

    # Filter by category if provided
    posts = posts.with_category(params[:category]) if params[:category].present?

    total_count = posts.count
    paginated_posts = posts.offset((page - 1) * per_page).limit(per_page)

    json_response({
      profile: blog_profile_data(user),
      posts: paginated_posts.map { |post| PostSerializer.summary(post, current_user: current_user) },
      pagination: {
        current_page: page,
        per_page: per_page,
        total_count: total_count,
        total_pages: (total_count.to_f / per_page).ceil,
        has_next_page: page < (total_count.to_f / per_page).ceil,
        has_previous_page: page > 1
      },
      following: current_user&.following?(user)
    })
  end

  # GET /blogs/:username/:slug - Show post
  def show
    user = User.find_by!(username: params[:username])
    @post = user.posts.find_by!(slug: params[:slug])

    # Only show non-visible posts to owner
    unless @post.visible? || (current_user && @post.user_id == current_user.id)
      return render_not_found('Post not found')
    end

    json_response(PostSerializer.full(@post, current_user: current_user))
  end

  # GET /posts/:id - Get post by ID (owner only, for editing)
  def show_by_id
    json_response(PostSerializer.full(@post, current_user: current_user))
  end

  # POST /posts - Create post
  def create
    require_ability!(:create_blog_post) and return if performed?

    @post = current_user.posts.build(post_params)

    # Check abilities for specific features
    if post_params[:status] == 'draft'
      require_ability!(:draft_posts) and return if performed?
    end

    if post_params[:status] == 'scheduled'
      require_ability!(:schedule_post) and return if performed?
    end

    if params[:post][:featured_image].present?
      require_ability!(:attach_images) and return if performed?
    end

    if post_params[:tags].present? || post_params[:categories].present?
      require_ability!(:manage_tags) and return if performed?
    end

    attach_track_if_song_present

    if @post.save
      attach_featured_image if params[:post][:featured_image].present?
      json_response(PostSerializer.full(@post, current_user: current_user), :created)
    else
      render_errors(@post)
    end
  end

  # PATCH /posts/:id - Update post
  def update
    # Check abilities for specific features being updated
    if post_params[:status] == 'draft'
      require_ability!(:draft_posts) and return if performed?
    end

    if post_params[:status] == 'scheduled'
      require_ability!(:schedule_post) and return if performed?
    end

    if params[:post][:featured_image].present?
      require_ability!(:attach_images) and return if performed?
    end

    if post_params[:tags].present? || post_params[:categories].present?
      require_ability!(:manage_tags) and return if performed?
    end

    @post.assign_attributes(post_params)
    attach_track_if_song_present

    if @post.save
      attach_featured_image if params[:post][:featured_image].present?
      json_response(PostSerializer.full(@post, current_user: current_user))
    else
      render_errors(@post)
    end
  end

  # DELETE /posts/:id - Delete post
  def destroy
    @post.destroy
    head :no_content
  end

  # GET /posts/my - Current user's posts (all statuses) with pagination
  def my_posts
    page = (params[:page] || 1).to_i
    per_page = (params[:per_page] || 20).to_i
    per_page = [per_page, 100].min

    posts = current_user.posts.order(created_at: :desc)

    # Filter by status if provided
    posts = posts.where(status: params[:status]) if params[:status].present?

    total_count = posts.count
    paginated_posts = posts.offset((page - 1) * per_page).limit(per_page)

    json_response({
      posts: paginated_posts.map { |post| PostSerializer.for_management(post) },
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

  private

  def set_post
    @post = Post.find(params[:id])
  end

  def post_params
    permitted = params.require(:post).permit(
      :title,
      :slug,
      :excerpt,
      :body,
      :publish_date,
      :status,
      :featured,
      :featured_image,
      :song_name,
      :band_name,
      :album_name,
      :artwork_url,
      :song_artwork_url,
      :song_link,
      tags: [],
      categories: [],
      authors: [:name, :url]
    )

    # Accept song_artwork_url as alias for artwork_url
    if permitted[:song_artwork_url].present? && permitted[:artwork_url].blank?
      permitted[:artwork_url] = permitted.delete(:song_artwork_url)
    else
      permitted.delete(:song_artwork_url)
    end

    permitted
  end

  def attach_featured_image
    return unless params[:post][:featured_image].present?

    @post.featured_image.attach(params[:post][:featured_image])
  end

  def blog_profile_data(user)
    {
      username: user.username,
      display_name: user.display_name,
      about_me: user.about_me,
      profile_image_url: user.profile_image.attached? ? url_for(user.profile_image) : nil,
      role: user.role,
      location: user.location,
      followers_count: user.followers.count,
      following_count: user.following.count,
      posts_count: user.posts.visible.count,
      member_since: user.created_at.iso8601
    }
  end

  def attach_track_if_song_present
    # Clear track if song is being removed
    unless @post.song_name.present? && @post.band_name.present?
      @post.track = nil
      return
    end

    band = find_or_create_band(@post.band_name)
    @post.track = find_or_create_track(band, @post.song_name) if band
  end

  # TrackFinder overrides for post params
  def band_lastfm_artist_name
    params.dig(:post, :band_lastfm_artist_name)
  end

  def band_musicbrainz_id
    params.dig(:post, :band_musicbrainz_id)
  end
end
