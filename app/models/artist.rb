# frozen_string_literal: true

# Canonical artist data from MusicBrainz
# Note: This is separate from Band model which represents artists on the platform
class Artist < ApplicationRecord
  has_many :albums, dependent: :destroy
  has_many :tracks, dependent: :destroy

  validates :name, presence: true
  validates :musicbrainz_artist_id, uniqueness: true, allow_nil: true
end
