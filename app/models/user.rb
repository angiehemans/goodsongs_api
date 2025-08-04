# app/models/user.rb
class User < ApplicationRecord
  has_secure_password
  has_many :reviews, dependent: :destroy
  has_many :bands, dependent: :destroy
  has_one_attached :profile_image
  
  validates :email, presence: true, uniqueness: { case_sensitive: false }
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :username, presence: true, uniqueness: { case_sensitive: false }
  validates :username, format: { with: /\A[a-zA-Z0-9_]+\z/, message: "only allows letters, numbers, and underscores" }
  validates :password, length: { minimum: 6 }, if: -> { new_record? || !password.nil? }
  validates :about_me, length: { maximum: 500 }
  
  before_save :downcase_email, :downcase_username

  def profile_data
    UserSerializer.profile_data(self)
  end

  def public_profile_data
    UserSerializer.public_profile(self)
  end
  
  private
  
  def downcase_email
    self.email = email.downcase
  end
  
  def downcase_username
    self.username = username.downcase
  end
end
