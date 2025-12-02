class QueryService
  def self.reviews_with_associations(scope = Review)
    scope.from_active_users.includes(:user, :band).order(created_at: :desc)
  end

  def self.bands_with_associations(scope = Band)
    scope.includes(:reviews, :user).order(:name)
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
    scope.includes(:reviews, :user).order(:name)
  end

  # For band pages - only show reviews from active users
  def self.band_reviews_from_active_users(band)
    band.reviews.from_active_users.includes(:user).order(created_at: :desc)
  end
end