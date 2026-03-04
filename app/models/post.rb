class Post < ApplicationRecord
  belongs_to :user
  belongs_to :track, optional: true
  has_one_attached :featured_image
  has_many :post_likes, dependent: :destroy
  has_many :likers, through: :post_likes, source: :user
  has_many :post_comments, dependent: :destroy
  has_many :page_views, as: :viewable, dependent: :destroy

  enum :status, { draft: 0, published: 1, scheduled: 2 }

  validates :title, presence: true
  validates :slug, presence: true,
                   uniqueness: { scope: :user_id },
                   format: { with: /\A[a-z0-9\-]+\z/, message: "can only contain lowercase letters, numbers, and hyphens" }
  validates :body, presence: true, if: :published?
  validates :publish_date, presence: true, if: :scheduled?
  validate :publish_date_in_future, if: :scheduled?

  before_validation :generate_slug

  # Scopes
  scope :visible, -> { where(status: :published).where('publish_date IS NULL OR publish_date <= ?', Time.current) }
  scope :published_posts, -> { where(status: :published) }
  scope :newest_featured_first, -> {
    order(
      Arel.sql('CASE WHEN featured = true THEN 0 ELSE 1 END'),
      publish_date: :desc,
      created_at: :desc
    )
  }
  scope :with_tag, ->(tag) { where('tags @> ?', [tag].to_json) }
  scope :with_category, ->(category) { where('categories @> ?', [category].to_json) }
  scope :ready_to_publish, -> { where(status: :scheduled).where('publish_date <= ?', Time.current) }

  def to_param
    slug
  end

  def has_song?
    song_name.present?
  end

  def likes_count
    post_likes.count
  end

  def liked_by?(user)
    return false unless user
    post_likes.exists?(user_id: user.id)
  end

  def comments_count
    post_comments.count
  end

  # Check if post is visible to public
  def visible?
    published? && (publish_date.nil? || publish_date <= Time.current)
  end

  # Returns authors if present, otherwise defaults to owner info
  def effective_authors
    return authors if authors.present?

    [{
      'name' => user.display_name,
      'url' => nil
    }]
  end

  def featured_image_url
    return nil unless featured_image.attached?

    Rails.application.routes.url_helpers.rails_blob_url(
      featured_image,
      **active_storage_url_options
    )
  end

  private

  def active_storage_url_options
    if ENV['API_URL'].present?
      uri = URI.parse(ENV['API_URL'])
      port_suffix = [80, 443].include?(uri.port) ? '' : ":#{uri.port}"
      { host: "#{uri.host}#{port_suffix}", protocol: uri.scheme }
    else
      Rails.env.production? ? { host: 'api.goodsongs.app', protocol: 'https' } : { host: 'localhost:3000', protocol: 'http' }
    end
  end

  def generate_slug
    return if title.blank?

    # If user provided a custom slug, normalize it but don't auto-generate
    if slug.present? && !slug_should_be_auto_generated?
      self.slug = normalize_slug(slug)
      return
    end

    # Auto-generate slug from title
    base_slug = normalize_slug(title)
    base_slug = 'post' if base_slug.blank?

    # Check if base slug is available within user scope
    if slug.blank? || slug_should_be_auto_generated?
      candidate_slug = base_slug
      counter = 1

      while user && Post.where(user_id: user_id, slug: candidate_slug).where.not(id: id).exists?
        candidate_slug = "#{base_slug}-#{counter}"
        counter += 1
      end

      self.slug = candidate_slug
    end
  end

  def normalize_slug(text)
    text.downcase.gsub(/[^a-z0-9\-]/, '-').gsub(/-+/, '-').gsub(/^-+|-+$/, '')
  end

  def slug_should_be_auto_generated?
    slug.blank? || (title_changed? && !slug_changed?)
  end

  def publish_date_in_future
    return unless publish_date.present? && publish_date <= Time.current

    errors.add(:publish_date, 'must be in the future for scheduled posts')
  end
end
