# frozen_string_literal: true

class AddStreamingLinksToTracks < ActiveRecord::Migration[8.0]
  def change
    add_column :tracks, :streaming_links, :jsonb, default: {}
    add_column :tracks, :songlink_url, :string
    add_column :tracks, :streaming_links_fetched_at, :datetime

    add_index :tracks, :streaming_links_fetched_at,
              where: "isrc IS NOT NULL AND streaming_links_fetched_at IS NULL",
              name: "index_tracks_needing_streaming_links"
    add_index :tracks, :streaming_links, using: :gin
  end
end
