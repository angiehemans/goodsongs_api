# frozen_string_literal: true

class ArtworkController < ApplicationController
  include ResourceController

  # POST /artwork/refresh/track/:id
  # Refresh artwork for a specific track
  # Params:
  #   - force: when "true", refresh even if artwork already exists
  def refresh_track
    track = Track.find(params[:id])

    # Verify user has permission (owns a scrobble of this track)
    unless current_user.scrobbles.exists?(track_id: track.id) || current_user.admin?
      return json_response({ error: 'You do not have permission to refresh artwork for this track' }, :forbidden)
    end

    # Force refresh by clearing existing artwork first
    if params[:force] == 'true' && track.album.present?
      track.album.update!(cover_art_url: nil)
    end

    result = ArtworkRefreshService.refresh_for_track(track)

    json_response({
      status: result[:status],
      message: result[:message] || status_message(result[:status]),
      artwork_url: result[:artwork_url],
      track: {
        id: track.id,
        name: track.name,
        album: track.album ? {
          id: track.album.id,
          name: track.album.name,
          cover_art_url: track.album.reload.cover_art_url
        } : nil
      }
    })
  end

  # POST /artwork/refresh/album/:id
  # Refresh artwork for a specific album
  # Params:
  #   - force: when "true", refresh even if artwork already exists
  def refresh_album
    album = Album.find(params[:id])

    # Verify user has permission (owns a scrobble of a track from this album)
    track_ids = album.tracks.pluck(:id)
    unless current_user.scrobbles.where(track_id: track_ids).exists? || current_user.admin?
      return json_response({ error: 'You do not have permission to refresh artwork for this album' }, :forbidden)
    end

    # Force refresh by clearing existing artwork first
    if params[:force] == 'true'
      album.update!(cover_art_url: nil)
    end

    result = ArtworkRefreshService.refresh_for_album(album)

    json_response({
      status: result[:status],
      message: result[:message] || status_message(result[:status]),
      artwork_url: result[:artwork_url],
      album: {
        id: album.id,
        name: album.name,
        cover_art_url: album.reload.cover_art_url
      }
    })
  end

  # POST /artwork/refresh/scrobble/:id
  # Refresh artwork for a scrobble's track (alternative to the API v1 endpoint)
  # Params:
  #   - force: when "true", refresh even if artwork already exists
  def refresh_scrobble
    scrobble = current_user.scrobbles.find(params[:id])

    # Force refresh by clearing existing artwork first
    if params[:force] == 'true' && scrobble.track&.album.present?
      scrobble.track.album.update!(cover_art_url: nil)
    end

    result = ArtworkRefreshService.refresh_for_scrobble(scrobble)

    # Invalidate cache if successful
    if result[:status] == 'success'
      ScrobbleCacheService.invalidate_recent_scrobbles(current_user.id)
    end

    json_response({
      status: result[:status],
      message: result[:message] || status_message(result[:status]),
      artwork_url: result[:artwork_url],
      scrobble: scrobble.track ? {
        id: scrobble.id,
        track: {
          id: scrobble.track.id,
          name: scrobble.track.name,
          album: scrobble.track.album ? {
            id: scrobble.track.album.id,
            name: scrobble.track.album.name,
            cover_art_url: scrobble.track.album.reload.cover_art_url
          } : nil
        }
      } : nil
    })
  end

  private

  def status_message(status)
    case status
    when 'success'
      'Artwork refreshed successfully'
    when 'already_has_artwork'
      'This item already has artwork'
    when 'not_found'
      'Could not find artwork from any source'
    when 'no_track'
      'No track metadata available'
    else
      'Unknown status'
    end
  end
end
