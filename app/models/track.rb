# frozen_string_literal: true

# Canonical track data from MusicBrainz
class Track < ApplicationRecord
  belongs_to :band, optional: true
  belongs_to :album, optional: true
  belongs_to :submitted_by, class_name: 'User', optional: true
  has_many :scrobbles, dependent: :nullify
  has_many :reviews, dependent: :nullify

  enum :source, { musicbrainz: 0, user_submitted: 1 }

  validates :name, presence: true
  validates :musicbrainz_recording_id, uniqueness: true, allow_nil: true

  scope :search_by_name, ->(query) {
    where("name % ?", query)
      .order(Arel.sql("similarity(name, #{connection.quote(query)}) DESC"))
  }
end
