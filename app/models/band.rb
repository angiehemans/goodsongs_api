class Band < ApplicationRecord
  belongs_to :user, optional: true
  has_many :reviews, dependent: :destroy
  has_one_attached :profile_picture
  
  validates :name, presence: true, uniqueness: { case_sensitive: false }
  validates :slug, presence: true, uniqueness: true, format: { with: /\A[a-z0-9\-_]+\z/, message: "can only contain lowercase letters, numbers, hyphens, and underscores" }
  validates :spotify_link, format: { with: /\Ahttps:\/\/(open\.)?spotify\.com\//, message: "must be a valid Spotify URL" }, allow_blank: true
  validates :bandcamp_link, format: { with: /\Ahttps:\/\/.*\.bandcamp\.com\//, message: "must be a valid Bandcamp URL" }, allow_blank: true
  validates :apple_music_link, format: { with: /\Ahttps:\/\/music\.apple\.com\//, message: "must be a valid Apple Music URL" }, allow_blank: true
  validates :youtube_music_link, format: { with: /\Ahttps:\/\/music\.youtube\.com\//, message: "must be a valid YouTube Music URL" }, allow_blank: true
  
  before_validation :generate_slug
  
  scope :user_created, -> { where.not(user_id: nil) }
  scope :auto_generated, -> { where(user_id: nil) }
  
  def user_owned?
    user_id.present?
  end
  
  def auto_generated?
    user_id.nil?
  end
  
  def to_param
    slug
  end
  
  private
  
  def generate_slug
    return if name.blank?
    
    # If user provided a custom slug, normalize it but don't auto-generate
    if slug.present? && !slug_should_be_auto_generated?
      self.slug = normalize_slug(slug)
      return
    end
    
    # Auto-generate slug from name
    base_slug = normalize_slug(name)
    base_slug = 'band' if base_slug.blank?
    
    # Check if base slug is available
    if slug.blank? || slug_should_be_auto_generated?
      candidate_slug = base_slug
      counter = 1
      
      while Band.where(slug: candidate_slug).where.not(id: id).exists?
        candidate_slug = "#{base_slug}-#{id || counter}"
        counter += 1
      end
      
      self.slug = candidate_slug
    end
  end
  
  def normalize_slug(text)
    text.downcase.gsub(/[^a-z0-9\-_]/, '-').gsub(/-+/, '-').gsub(/^-+|-+$/, '')
  end
  
  def slug_should_be_auto_generated?
    # Auto-generate if slug is blank or if name changed and slug wasn't manually set
    slug.blank? || (name_changed? && !slug_changed?)
  end
end
