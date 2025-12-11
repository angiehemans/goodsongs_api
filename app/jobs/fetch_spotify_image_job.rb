class FetchSpotifyImageJob < ApplicationJob
  queue_as :default

  def perform(band_id)
    band = Band.find_by(id: band_id)
    return unless band&.spotify_link.present?

    image_url = SpotifyArtistService.fetch_artist_image(band.spotify_link)
    return unless image_url

    band.update_column(:spotify_image_url, image_url)
  end
end
