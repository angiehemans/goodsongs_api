# frozen_string_literal: true

# Canonical album data from MusicBrainz
class Album < ApplicationRecord
  belongs_to :artist, optional: true
  has_many :tracks, dependent: :nullify

  validates :name, presence: true
  validates :musicbrainz_release_id, uniqueness: true, allow_nil: true
end
