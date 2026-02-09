# app/controllers/admin_controller.rb
class AdminController < ApplicationController
  before_action :require_admin

  # GET /admin/users
  # Params:
  #   - q: search query for username or email (optional)
  #   - page, per_page: pagination
  def users
    page = (params[:page] || 1).to_i
    per_page = (params[:per_page] || 20).to_i
    per_page = [per_page, 100].min
    query = params[:q]&.strip.presence

    users = User.all

    if query.present?
      # Search by username or email using trigram similarity
      users = users
                .where("username % ? OR email % ?", query, query)
                .order(Arel.sql("GREATEST(similarity(COALESCE(username, ''), #{User.connection.quote(query)}), similarity(email, #{User.connection.quote(query)})) DESC"))
    else
      users = users.order(created_at: :desc)
    end

    total_count = users.count
    paginated_users = users.offset((page - 1) * per_page).limit(per_page)

    json_response({
      users: paginated_users.map { |user| admin_user_data(user) },
      pagination: pagination_meta(page, per_page, total_count),
      query: query
    })
  end

  # GET /admin/users/:id
  def user_detail
    user = User.find(params[:id])
    reviews = user.reviews.includes(:band).order(created_at: :desc)
    bands = user.bands.order(:name)

    json_response({
      user: admin_user_data_full(user),
      reviews: reviews.map { |review| ReviewSerializer.full(review, current_user: current_user) },
      bands: bands.map { |band| admin_band_data(band) }
    })
  end

  # PATCH /admin/users/:id/toggle-disabled
  def toggle_disabled
    user = User.find(params[:id])

    # Prevent admin from disabling themselves
    if user.id == current_user.id
      return json_response({ error: 'You cannot disable your own account' }, :unprocessable_entity)
    end

    user.update!(disabled: !user.disabled)

    json_response({
      message: user.disabled? ? 'User has been disabled' : 'User has been enabled',
      user: admin_user_data(user)
    })
  end

  # PATCH /admin/users/:id
  def update_user
    user = User.find(params[:id])

    # Prevent admin from modifying their own admin status
    if user.id == current_user.id && params[:admin].present? && params[:admin] != user.admin?
      return json_response({ error: 'You cannot modify your own admin status' }, :unprocessable_entity)
    end

    if user.update(admin_user_params)
      json_response({
        message: 'User has been updated',
        user: admin_user_data_full(user)
      })
    else
      json_response({ errors: user.errors.full_messages }, :unprocessable_entity)
    end
  end

  # DELETE /admin/users/:id
  def destroy_user
    user = User.find(params[:id])

    # Prevent admin from deleting themselves
    if user.id == current_user.id
      return json_response({ error: 'You cannot delete your own account' }, :unprocessable_entity)
    end

    user.destroy!
    json_response({ message: 'User has been deleted' })
  end

  # GET /admin/bands
  # Params:
  #   - q or search: search query for band name (optional, uses trigram similarity)
  #   - find_duplicates: when "true", groups bands by normalized name to find potential duplicates
  #   - duplicate_mbids: when "true", finds bands sharing the same MusicBrainz ID
  #   - page, per_page: pagination
  def bands
    page = (params[:page] || 1).to_i
    per_page = (params[:per_page] || 20).to_i
    per_page = [per_page, 100].min
    query = (params[:q] || params[:search])&.strip.presence

    # Find potential duplicate bands by normalized name
    if params[:find_duplicates] == 'true'
      return find_duplicate_bands(page, per_page)
    end

    # Find bands with duplicate MusicBrainz IDs
    if params[:duplicate_mbids] == 'true'
      return find_duplicate_mbid_bands(page, per_page)
    end

    bands = Band.all.includes(:user, :reviews)

    # Search filter using trigram similarity
    if query.present?
      bands = bands
                .where("name % ?", query)
                .order(Arel.sql("similarity(name, #{Band.connection.quote(query)}) DESC"))
    else
      bands = bands.order(:name)
    end

    total_count = bands.count
    paginated_bands = bands.offset((page - 1) * per_page).limit(per_page)

    json_response({
      bands: paginated_bands.map { |band| admin_band_data(band) },
      pagination: pagination_meta(page, per_page, total_count),
      query: query
    })
  end

  # GET /admin/bands/:id
  def band_detail
    band = Band.find(params[:id])
    reviews = band.reviews.includes(:user).order(created_at: :desc)
    events = band.events.includes(:venue).order(event_date: :desc)

    json_response({
      band: admin_band_data_full(band),
      reviews: reviews.map { |review| ReviewSerializer.full(review, current_user: current_user) },
      events: events.map { |event| EventSerializer.full(event) }
    })
  end

  # PATCH /admin/bands/:id
  def update_band
    band = Band.find(params[:id])

    if band.update(admin_band_params)
      json_response({
        message: 'Band has been updated',
        band: admin_band_data_full(band)
      })
    else
      json_response({ errors: band.errors.full_messages }, :unprocessable_entity)
    end
  end

  # PATCH /admin/bands/:id/toggle-disabled
  def toggle_band_disabled
    band = Band.find(params[:id])
    band.update!(disabled: !band.disabled)

    json_response({
      message: band.disabled? ? 'Band has been disabled' : 'Band has been enabled',
      band: admin_band_data(band)
    })
  end

  # DELETE /admin/bands/:id
  def destroy_band
    band = Band.find(params[:id])

    # Nullify primary_band reference for any users who have this as their primary band
    User.where(primary_band_id: band.id).update_all(primary_band_id: nil)

    band.destroy!
    json_response({ message: 'Band has been deleted' })
  end

  # POST /admin/bands/:id/enrich
  # Manually trigger enrichment for a band (fetches MusicBrainz data, images, streaming links, etc.)
  def enrich_band
    band = Band.find(params[:id])

    # Queue the enrichment job
    FetchArtistImageJob.perform_later(band.id)

    json_response({
      message: "Enrichment job queued for '#{band.name}'",
      band: admin_band_data(band)
    })
  end

  # GET /admin/reviews
  # Params:
  #   - q: search query for band name or song name (optional)
  #   - page, per_page: pagination
  def reviews
    page = (params[:page] || 1).to_i
    per_page = (params[:per_page] || 20).to_i
    per_page = [per_page, 100].min
    query = params[:q]&.strip.presence

    reviews = Review.all.includes(:user, :band)

    if query.present?
      # Search by band_name or song_name using trigram similarity
      reviews = reviews
                  .where("band_name % ? OR song_name % ?", query, query)
                  .order(Arel.sql("GREATEST(similarity(band_name, #{Review.connection.quote(query)}), similarity(song_name, #{Review.connection.quote(query)})) DESC"))
    else
      reviews = reviews.order(created_at: :desc)
    end

    total_count = reviews.count
    paginated_reviews = reviews.offset((page - 1) * per_page).limit(per_page)

    json_response({
      reviews: paginated_reviews.map { |review| ReviewSerializer.full(review, current_user: current_user) },
      pagination: pagination_meta(page, per_page, total_count),
      query: query
    })
  end

  # DELETE /admin/reviews/:id
  def destroy_review
    review = Review.find(params[:id])
    review.destroy!
    json_response({ message: 'Review has been deleted' })
  end

  # POST /admin/reviews/:id/enrich
  # Manually trigger enrichment for the band associated with a review
  def enrich_review
    review = Review.find(params[:id])
    band = review.band

    unless band
      return json_response({ error: 'Review has no associated band' }, :unprocessable_entity)
    end

    # Queue the band enrichment job
    FetchArtistImageJob.perform_later(band.id)

    # Try to look up track metadata from MusicBrainz
    track_info = lookup_track_metadata(review.song_name, review.band_name)

    json_response({
      message: "Enrichment job queued for band '#{band.name}'",
      band: admin_band_data(band),
      track_lookup: track_info
    })
  end

  private

  # Find bands with similar/duplicate names for manual deduplication
  def find_duplicate_bands(page, per_page)
    all_bands = Band.all.includes(:user, :reviews).order(:name)

    # Group bands by normalized name
    grouped = all_bands.group_by { |band| normalize_band_name(band.name) }

    # Filter to only groups with potential duplicates (more than 1 band)
    duplicate_groups = grouped.select { |_normalized, bands| bands.size > 1 }

    # Flatten and sort by normalized name for consistent ordering
    duplicate_bands = duplicate_groups.flat_map do |normalized_name, bands|
      bands.map { |band| { band: band, normalized_name: normalized_name, group_size: bands.size } }
    end.sort_by { |entry| [entry[:normalized_name], entry[:band].name] }

    total_count = duplicate_bands.size
    paginated = duplicate_bands.slice((page - 1) * per_page, per_page) || []

    json_response({
      bands: paginated.map do |entry|
        admin_band_data(entry[:band]).merge(
          normalized_name: entry[:normalized_name],
          duplicate_group_size: entry[:group_size]
        )
      end,
      pagination: pagination_meta(page, per_page, total_count),
      duplicate_groups_count: duplicate_groups.size,
      total_duplicate_bands: total_count
    })
  end

  # Find bands that share the same MusicBrainz ID
  def find_duplicate_mbid_bands(page, per_page)
    # Find musicbrainz_ids that appear more than once
    duplicate_mbids = Band.where.not(musicbrainz_id: [nil, ''])
                          .group(:musicbrainz_id)
                          .having('COUNT(*) > 1')
                          .count
                          .keys

    if duplicate_mbids.empty?
      return json_response({
        bands: [],
        pagination: pagination_meta(page, per_page, 0),
        duplicate_mbid_count: 0,
        total_duplicate_bands: 0
      })
    end

    # Get all bands with those duplicate MBIDs
    bands = Band.where(musicbrainz_id: duplicate_mbids)
                .includes(:user, :reviews)
                .order(:musicbrainz_id, :name)

    total_count = bands.count
    paginated_bands = bands.offset((page - 1) * per_page).limit(per_page)

    # Count how many bands share each MBID for the response
    mbid_counts = Band.where(musicbrainz_id: duplicate_mbids).group(:musicbrainz_id).count

    json_response({
      bands: paginated_bands.map do |band|
        admin_band_data(band).merge(
          duplicate_mbid_count: mbid_counts[band.musicbrainz_id]
        )
      end,
      pagination: pagination_meta(page, per_page, total_count),
      duplicate_mbid_count: duplicate_mbids.size,
      total_duplicate_bands: total_count
    })
  end

  # Look up track metadata from MusicBrainz
  def lookup_track_metadata(track_name, artist_name)
    return { status: 'skipped', message: 'Missing track or artist name' } if track_name.blank? || artist_name.blank?

    recording = ScrobbleCacheService.get_musicbrainz_recording(track_name, artist_name)

    if recording
      {
        status: 'found',
        mbid: recording[:mbid],
        title: recording[:title],
        artist: recording[:artists]&.first&.dig(:name),
        album: recording[:releases]&.first&.dig(:title),
        duration_ms: recording[:length]
      }
    else
      { status: 'not_found', message: "No MusicBrainz match for '#{track_name}' by '#{artist_name}'" }
    end
  rescue StandardError => e
    { status: 'error', message: e.message }
  end

  # Normalize band name for duplicate detection
  # Removes: "The ", leading/trailing whitespace, punctuation, asterisks, and lowercases
  def normalize_band_name(name)
    return '' if name.blank?

    normalized = name.downcase.strip
    # Remove common prefixes
    normalized = normalized.sub(/^the\s+/, '')
    # Remove trailing asterisks, punctuation marks
    normalized = normalized.gsub(/[\*\.\!\?\,\'\"\-\_]+$/, '')
    # Remove all non-alphanumeric characters except spaces
    normalized = normalized.gsub(/[^a-z0-9\s]/, '')
    # Normalize multiple spaces to single space
    normalized = normalized.gsub(/\s+/, ' ').strip

    normalized
  end

  def pagination_meta(page, per_page, total_count)
    total_pages = (total_count.to_f / per_page).ceil
    {
      current_page: page,
      per_page: per_page,
      total_count: total_count,
      total_pages: total_pages,
      has_next_page: page < total_pages,
      has_previous_page: page > 1
    }
  end

  def admin_user_params
    params.permit(
      :email,
      :username,
      :about_me,
      :city,
      :region,
      :admin,
      :disabled,
      :account_type,
      :lastfm_username,
      :onboarding_completed,
      :profile_image
    )
  end

  def admin_user_data(user)
    UserSerializer.public_profile(user).merge(
      admin: user.admin?,
      disabled: user.disabled?
    )
  end

  # Full user data for admin editing - includes all editable fields
  def admin_user_data_full(user)
    {
      id: user.id,
      email: user.email,
      username: user.username,
      about_me: user.about_me,
      city: user.city,
      region: user.region,
      location: user.location,
      latitude: user.latitude,
      longitude: user.longitude,
      account_type: user.account_type,
      onboarding_completed: user.onboarding_completed,
      admin: user.admin?,
      disabled: user.disabled?,
      lastfm_username: user.lastfm_username,
      lastfm_connected: user.lastfm_connected?,
      profile_image_url: UserSerializer.profile_image_url(user),
      display_name: user.display_name,
      reviews_count: user.reviews.count,
      bands_count: user.bands.count,
      followers_count: user.followers.count,
      following_count: user.following.count,
      created_at: user.created_at,
      updated_at: user.updated_at
    }
  end

  def admin_band_params
    params.permit(
      :name,
      :slug,
      :about,
      :city,
      :region,
      :disabled,
      :user_id,
      :spotify_link,
      :bandcamp_link,
      :bandcamp_embed,
      :apple_music_link,
      :youtube_music_link,
      :musicbrainz_id,
      :lastfm_artist_name,
      :artist_image_url,
      :profile_picture
    )
  end

  def admin_band_data(band)
    BandSerializer.full(band).merge(
      disabled: band.disabled?
    )
  end

  # Full band data for admin editing - includes all editable fields
  def admin_band_data_full(band)
    {
      id: band.id,
      name: band.name,
      slug: band.slug,
      about: band.about,
      city: band.city,
      region: band.region,
      location: band.location,
      latitude: band.latitude,
      longitude: band.longitude,
      disabled: band.disabled?,
      user_id: band.user_id,
      user_owned: band.user_owned?,
      owner: band.user ? { id: band.user.id, username: band.user.username, email: band.user.email } : nil,
      spotify_link: band.spotify_link,
      bandcamp_link: band.bandcamp_link,
      bandcamp_embed: band.bandcamp_embed,
      apple_music_link: band.apple_music_link,
      youtube_music_link: band.youtube_music_link,
      musicbrainz_id: band.musicbrainz_id,
      lastfm_artist_name: band.lastfm_artist_name,
      lastfm_url: band.lastfm_url,
      artist_image_url: band.artist_image_url,
      profile_picture_url: BandSerializer.band_image_url(band),
      reviews_count: band.reviews.count,
      events_count: band.events.count,
      created_at: band.created_at,
      updated_at: band.updated_at
    }
  end
end
