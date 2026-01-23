# frozen_string_literal: true

# Canonical track data from MusicBrainz
class Track < ApplicationRecord
  belongs_to :artist, optional: true
  belongs_to :album, optional: true
  has_many :scrobbles, dependent: :nullify

  validates :name, presence: true
  validates :musicbrainz_recording_id, uniqueness: true, allow_nil: true
end
