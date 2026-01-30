# frozen_string_literal: true

# Canonical album data from MusicBrainz
class Album < ApplicationRecord
  belongs_to :band, optional: true
  belongs_to :submitted_by, class_name: 'User', optional: true
  has_many :tracks, dependent: :nullify

  enum :source, { musicbrainz: 0, user_submitted: 1 }

  validates :name, presence: true
  validates :musicbrainz_release_id, uniqueness: true, allow_nil: true
  validates :discogs_master_id, uniqueness: true, allow_nil: true
  validates :release_type, inclusion: {
    in: %w[album single ep compilation live remix soundtrack other],
    allow_nil: true
  }

  scope :search_by_name, ->(query) {
    where("name % ?", query)
      .order(Arel.sql("similarity(name, #{connection.quote(query)}) DESC"))
  }
end
