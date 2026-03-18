class QueryService
  def self.reviews_with_associations(scope = Review)
    scope.from_active_users.includes(:user, :band, :track, :mentions, :review_likes, :review_comments).order(created_at: :desc)
  end

  def self.bands_with_associations(scope = Band)
    scope.where(disabled: false).includes(:reviews, :user).order(:name)
  end

  def self.user_bands_with_reviews(user)
    user.bands.includes(:reviews).order(created_at: :desc)
  end

  def self.user_reviews_with_associations(user)
    user.reviews.includes(:band, :track, :mentions, :review_likes, :review_comments).order(created_at: :desc)
  end

  def self.recent_reviews(limit: 50)
    reviews_with_associations.limit(limit)
  end

  def self.bands_ordered_by_name(scope = Band)
    scope.where(disabled: false).includes(:reviews, :user).order(:name)
  end

  # For band pages - only show reviews from active users
  def self.band_reviews_from_active_users(band)
    band.reviews.from_active_users.includes(:user, :track, :mentions, :review_likes, :review_comments).order(created_at: :desc)
  end

  # Combined feed - user's own reviews + reviews from users I follow + reviews about bands owned by users I follow
  # Returns paginated results
  def self.following_feed(user, page: 1, per_page: 20)
    following_feed_scope(user)
      .includes(:user, :band)
      .order(created_at: :desc)
      .offset((page - 1) * per_page)
      .limit(per_page)
  end

  # Count total reviews in following feed for pagination metadata
  def self.following_feed_count(user)
    following_feed_scope(user).count
  end

  # Unified following feed: reviews + posts + events from followed users
  # Returns paginated array of { type:, record: } hashes sorted by created_at DESC
  def self.unified_following_feed(user, page: 1, per_page: 20)
    items = unified_following_feed_items(user)
    offset = (page - 1) * per_page
    items.sort_by { |item| item[:record].created_at }.reverse.slice(offset, per_page) || []
  end

  # Count total items in unified following feed for pagination metadata
  def self.unified_following_feed_count(user)
    unified_following_feed_items(user).size
  end

  # Preview of unified feed (for dashboards)
  def self.unified_following_feed_preview(user, limit: 5)
    items = unified_following_feed_items(user)
    items.sort_by { |item| item[:record].created_at }.reverse.first(limit)
  end

  # Base scope for following feed queries
  def self.following_feed_scope(user)
    followed_user_ids = user.following.where(disabled: false).pluck(:id)
    followed_band_ids = Band.where(user_id: followed_user_ids).pluck(:id) if followed_user_ids.any?

    conditions = ['reviews.user_id = ?']
    values = [user.id]

    if followed_user_ids.any?
      conditions << 'reviews.user_id IN (?)'
      values << followed_user_ids
    end

    if followed_band_ids&.any?
      conditions << 'reviews.band_id IN (?)'
      values << followed_band_ids
    end

    Review.from_active_users.where(conditions.join(' OR '), *values)
  end
  private_class_method :following_feed_scope

  def self.unified_following_feed_items(user)
    followed_user_ids = user.following.where(disabled: false).pluck(:id)
    all_user_ids = [user.id] + followed_user_ids

    # Reviews: own + from followed users + about bands owned by followed users
    followed_band_ids = Band.where(user_id: followed_user_ids).pluck(:id) if followed_user_ids.any?
    review_conditions = ['reviews.user_id IN (?)']
    review_values = [all_user_ids]
    if followed_band_ids&.any?
      review_conditions << 'reviews.band_id IN (?)'
      review_values << followed_band_ids
    end
    reviews = Review.from_active_users
                    .includes(:user, :band, :track, :mentions, :review_likes)
                    .where(review_conditions.join(' OR '), *review_values)
                    .to_a

    # Posts: visible (published) posts from self + followed users
    posts = Post.visible
                .includes(:user, :post_likes, :track)
                .where(user_id: all_user_ids)
                .to_a

    # Events: events from self + followed users
    events = Event.includes(:user, :venue, :band)
                  .where(user_id: all_user_ids)
                  .to_a

    reviews.map { |r| { type: 'review', record: r } } +
      posts.map { |p| { type: 'post', record: p } } +
      events.map { |e| { type: 'event', record: e } }
  end
  private_class_method :unified_following_feed_items
end