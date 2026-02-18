class QueryService
  def self.reviews_with_associations(scope = Review)
    scope.from_active_users.includes(:user, :band).order(created_at: :desc)
  end

  def self.bands_with_associations(scope = Band)
    scope.where(disabled: false).includes(:reviews, :user).order(:name)
  end

  def self.user_bands_with_reviews(user)
    user.bands.includes(:reviews).order(created_at: :desc)
  end

  def self.user_reviews_with_associations(user)
    user.reviews.includes(:band).order(created_at: :desc)
  end

  def self.recent_reviews(limit: 50)
    reviews_with_associations.limit(limit)
  end

  def self.bands_ordered_by_name(scope = Band)
    scope.where(disabled: false).includes(:reviews, :user).order(:name)
  end

  # For band pages - only show reviews from active users
  def self.band_reviews_from_active_users(band)
    band.reviews.from_active_users.includes(:user).order(created_at: :desc)
  end

  # Combined feed - user's own reviews + reviews from users I follow + reviews about bands owned by users I follow
  # Returns paginated results
  def self.following_feed(user, page: 1, per_page: 20)
    followed_user_ids = user.following.where(disabled: false).pluck(:id)
    followed_band_ids = Band.where(user_id: followed_user_ids).pluck(:id) if followed_user_ids.any?

    # Build conditions: own reviews OR from followed users OR about followed bands
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

    Review.from_active_users
          .includes(:user, :band)
          .where(conditions.join(' OR '), *values)
          .order(created_at: :desc)
          .offset((page - 1) * per_page)
          .limit(per_page)
  end

  # Count total reviews in following feed for pagination metadata
  def self.following_feed_count(user)
    followed_user_ids = user.following.where(disabled: false).pluck(:id)
    followed_band_ids = Band.where(user_id: followed_user_ids).pluck(:id) if followed_user_ids.any?

    # Build conditions: own reviews OR from followed users OR about followed bands
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

    Review.from_active_users
          .where(conditions.join(' OR '), *values)
          .count
  end
end