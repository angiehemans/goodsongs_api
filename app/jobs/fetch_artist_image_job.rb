class FetchArtistImageJob < ApplicationJob
  queue_as :default

  # Retry on network errors
  retry_on Net::OpenTimeout, Net::ReadTimeout, OpenSSL::SSL::SSLError,
           Errno::ECONNRESET, Errno::ECONNREFUSED, SocketError,
           wait: :polynomially_longer, attempts: 3

  # MusicBrainz rate limit: 1 request per second
  # Add small delay between API calls
  MUSICBRAINZ_DELAY = 1.1

  def perform(band_id)
    band = Band.find_by(id: band_id)
    return unless band

    # Get or find MusicBrainz data
    artist_data = fetch_artist_data(band)
    return unless artist_data

    mbid = artist_data[:mbid]

    # Update band with MusicBrainz metadata
    update_band_metadata(band, artist_data)

    # Try to fetch image from Fanart.tv first (if API key is configured)
    image_url = FanartTvService.get_artist_thumb(mbid) if mbid

    # Fallback: Try to get image from Wikidata/Wikipedia via MusicBrainz URLs
    if image_url.blank? && artist_data[:urls]
      image_url = fetch_wikipedia_image(artist_data[:urls])
    end

    if image_url.present?
      band.update_column(:artist_image_url, image_url)
      Rails.logger.info("FetchArtistImageJob: Updated band #{band.id} (#{band.name}) with image")
    else
      Rails.logger.info("FetchArtistImageJob: No image found for band #{band.id} (#{band.name})")
    end
  end

  private

  def update_band_metadata(band, artist_data)
    updates = {}

    # MusicBrainz ID
    if artist_data[:mbid].present? && band.musicbrainz_id.blank?
      updates[:musicbrainz_id] = artist_data[:mbid]
    end

    # Location from area or begin_area (where band formed)
    if band.city.blank? && band.region.blank?
      location = artist_data[:begin_area] || artist_data[:area]
      if location.present?
        updates[:city] = location
      end

      # Country as region if we have it
      if artist_data[:country].present?
        updates[:region] = country_name(artist_data[:country])
      end
    end

    # About - try Wikipedia first for a real bio, fall back to genres
    if band.about.blank?
      about_text = fetch_wikipedia_bio(artist_data)
      if about_text.blank? && (artist_data[:genres].present? || artist_data[:tags].present?)
        genres = artist_data[:genres].presence || artist_data[:tags]&.first(5)
        about_text = "#{artist_data[:type] || 'Artist'} · #{genres.join(', ')}" if genres.present?
      end
      updates[:about] = about_text if about_text.present?
    end

    # Streaming/social links from MusicBrainz URLs
    urls = artist_data[:urls] || {}

    if band.bandcamp_link.blank? && urls['bandcamp'].present?
      updates[:bandcamp_link] = urls['bandcamp']
    end

    if band.spotify_link.blank? && urls['spotify'].present?
      updates[:spotify_link] = urls['spotify']
    end

    if band.apple_music_link.blank? && urls['apple_music'].present?
      updates[:apple_music_link] = urls['apple_music']
    end

    # Store Last.fm artist name for linking
    if band.lastfm_artist_name.blank? && artist_data[:name].present?
      updates[:lastfm_artist_name] = artist_data[:name]
    end

    # Apply updates if any
    if updates.any?
      band.update_columns(updates)
      Rails.logger.info("FetchArtistImageJob: Updated band #{band.id} metadata: #{updates.keys.join(', ')}")
    end
  end

  def fetch_wikipedia_bio(artist_data)
    urls = artist_data[:urls] || {}

    # Try Wikipedia URL from MusicBrainz
    if urls['wikipedia'].present?
      bio = fetch_wikipedia_summary(urls['wikipedia'])
      return bio if bio.present?
    end

    # Fallback: Try Wikidata to find Wikipedia article
    if urls['wikidata'].present?
      bio = fetch_bio_via_wikidata(urls['wikidata'])
      return bio if bio.present?
    end

    nil
  end

  def fetch_wikipedia_summary(wikipedia_url)
    # Extract language and page title from URL
    match = wikipedia_url.match(%r{//(\w+)\.wikipedia\.org/wiki/(.+)})
    return nil unless match

    lang = match[1]
    title = match[2]

    response = HTTParty.get(
      "https://#{lang}.wikipedia.org/api/rest_v1/page/summary/#{title}",
      headers: { 'User-Agent' => 'GoodSongs/1.0 (https://goodsongs.app)' }
    )

    return nil unless response.success?

    extract = response.parsed_response['extract']
    return nil if extract.blank?

    # Truncate to reasonable length for "about" field
    truncate_bio(extract)
  rescue StandardError => e
    Rails.logger.error("FetchArtistImageJob Wikipedia bio error: #{e.message}")
    nil
  end

  def fetch_bio_via_wikidata(wikidata_url)
    # Extract Wikidata ID
    match = wikidata_url.match(/Q\d+/)
    return nil unless match

    wikidata_id = match[0]

    # Get English Wikipedia article title from Wikidata
    response = HTTParty.get(
      "https://www.wikidata.org/wiki/Special:EntityData/#{wikidata_id}.json",
      headers: { 'User-Agent' => 'GoodSongs/1.0 (https://goodsongs.app)' }
    )

    return nil unless response.success?

    # Get the English Wikipedia sitelink
    wiki_title = response.parsed_response.dig('entities', wikidata_id, 'sitelinks', 'enwiki', 'title')
    return nil unless wiki_title.present?

    # Fetch the Wikipedia summary
    fetch_wikipedia_summary("https://en.wikipedia.org/wiki/#{ERB::Util.url_encode(wiki_title)}")
  rescue StandardError => e
    Rails.logger.error("FetchArtistImageJob Wikidata bio error: #{e.message}")
    nil
  end

  def truncate_bio(text, max_length: 500)
    return text if text.length <= max_length

    # Try to truncate at a sentence boundary
    truncated = text[0...max_length]
    last_period = truncated.rindex('. ')

    if last_period && last_period > max_length / 2
      truncated[0..last_period]
    else
      truncated.strip + '...'
    end
  end

  def country_name(country_code)
    # Map common country codes to names
    countries = {
      'US' => 'United States',
      'GB' => 'United Kingdom',
      'CA' => 'Canada',
      'AU' => 'Australia',
      'DE' => 'Germany',
      'FR' => 'France',
      'JP' => 'Japan',
      'SE' => 'Sweden',
      'NO' => 'Norway',
      'NL' => 'Netherlands',
      'IE' => 'Ireland',
      'NZ' => 'New Zealand',
      'IT' => 'Italy',
      'ES' => 'Spain',
      'BR' => 'Brazil',
      'MX' => 'Mexico',
      'KR' => 'South Korea',
      'BE' => 'Belgium',
      'AT' => 'Austria',
      'CH' => 'Switzerland',
      'DK' => 'Denmark',
      'FI' => 'Finland',
      'PT' => 'Portugal',
      'PL' => 'Poland',
      'RU' => 'Russia',
      'ZA' => 'South Africa',
      'AR' => 'Argentina',
      'CL' => 'Chile',
      'CO' => 'Colombia'
    }
    countries[country_code] || country_code
  end

  def fetch_artist_data(band)
    # If we already have an MBID, fetch the full data
    if band.musicbrainz_id.present?
      sleep(MUSICBRAINZ_DELAY)
      return MusicbrainzService.get_artist(band.musicbrainz_id)
    end

    # Otherwise search for the artist
    artist_name = band.lastfm_artist_name.presence || band.name
    return nil unless artist_name.present?

    sleep(MUSICBRAINZ_DELAY)
    MusicbrainzService.find_artist(artist_name)
  end

  def fetch_wikipedia_image(urls)
    # Try Wikidata first (more reliable for images)
    if urls['wikidata'].present?
      image = fetch_wikidata_image(urls['wikidata'])
      return image if image.present?
    end

    # Fallback to Wikipedia
    if urls['wikipedia'].present?
      image = fetch_wikipedia_page_image(urls['wikipedia'])
      return image if image.present?
    end

    nil
  end

  def fetch_wikidata_image(wikidata_url)
    # Extract Wikidata ID (e.g., Q44190 from https://www.wikidata.org/wiki/Q44190)
    match = wikidata_url.match(/Q\d+/)
    return nil unless match

    wikidata_id = match[0]

    response = HTTParty.get(
      "https://www.wikidata.org/wiki/Special:EntityData/#{wikidata_id}.json",
      headers: { 'User-Agent' => 'GoodSongs/1.0 (https://goodsongs.app)' }
    )

    return nil unless response.success?

    # Get the image filename from P18 (image property)
    image_filename = response.parsed_response.dig('entities', wikidata_id, 'claims', 'P18', 0, 'mainsnak', 'datavalue', 'value')
    return nil unless image_filename.present?

    # Convert filename to Wikimedia Commons URL
    wikimedia_image_url(image_filename)
  rescue StandardError => e
    Rails.logger.error("FetchArtistImageJob Wikidata error: #{e.message}")
    nil
  end

  def fetch_wikipedia_page_image(wikipedia_url)
    # Extract language and page title from URL
    # e.g., https://en.wikipedia.org/wiki/Radiohead
    match = wikipedia_url.match(%r{//(\w+)\.wikipedia\.org/wiki/(.+)})
    return nil unless match

    lang = match[1]
    title = match[2]

    response = HTTParty.get(
      "https://#{lang}.wikipedia.org/api/rest_v1/page/summary/#{title}",
      headers: { 'User-Agent' => 'GoodSongs/1.0 (https://goodsongs.app)' }
    )

    return nil unless response.success?

    # Get the thumbnail or original image
    response.parsed_response.dig('thumbnail', 'source') ||
      response.parsed_response.dig('originalimage', 'source')
  rescue StandardError => e
    Rails.logger.error("FetchArtistImageJob Wikipedia error: #{e.message}")
    nil
  end

  def wikimedia_image_url(filename)
    # Wikimedia Commons URL format for images
    # https://commons.wikimedia.org/wiki/Special:FilePath/Filename.jpg
    encoded_filename = ERB::Util.url_encode(filename.tr(' ', '_'))
    "https://commons.wikimedia.org/wiki/Special:FilePath/#{encoded_filename}?width=500"
  end
end
