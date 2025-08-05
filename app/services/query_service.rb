class QueryService
  def self.reviews_with_associations(scope = Review)
    scope.includes(:user, :band).order(created_at: :desc)
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
end