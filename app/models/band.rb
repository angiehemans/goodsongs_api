class Band < ApplicationRecord
  has_many :reviews, dependent: :destroy
  
  validates :name, presence: true, uniqueness: { case_sensitive: false }
end
