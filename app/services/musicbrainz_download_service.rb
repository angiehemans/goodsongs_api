# frozen_string_literal: true

require "net/http"
require "fileutils"

class MusicbrainzDownloadService
  BASE_URL = "https://data.musicbrainz.org/pub/musicbrainz/data/fullexport"

  ARCHIVES = {
    "mbdump.tar.bz2" => %w[
      mbdump/artist
      mbdump/artist_alias
      mbdump/artist_credit
      mbdump/artist_credit_name
      mbdump/recording
      mbdump/isrc
      mbdump/release_group
      mbdump/release
      mbdump/medium
      mbdump/track
      mbdump/release_country
      mbdump/area
      mbdump/iso_3166_1
      mbdump/artist_type
      mbdump/release_group_primary_type
      mbdump/release_status
    ],
    "mbdump-derived.tar.bz2" => %w[
      mbdump/tag
      mbdump/artist_tag
    ],
    "mbdump-cover-art-archive.tar.bz2" => %w[
      mbdump/cover_art_archive.cover_art
    ]
  }.freeze

  def initialize(dump_dir: nil, dump_date: nil)
    @dump_dir = dump_dir || Rails.root.join("tmp", "musicbrainz").to_s
    @dump_date = dump_date
  end

  def call
    FileUtils.mkdir_p(@dump_dir)

    date = resolve_dump_date
    Rails.logger.info "[MB Download] Using dump date: #{date}"

    ARCHIVES.each do |archive, members|
      download_archive(date, archive)
      extract_members(archive, members)
    end

    Rails.logger.info "[MB Download] All downloads and extractions complete"
  end

  private

  def resolve_dump_date
    return @dump_date if @dump_date.present? && @dump_date != "latest"

    Rails.logger.info "[MB Download] Resolving latest dump date..."
    uri = URI("#{BASE_URL}/LATEST")
    response = Net::HTTP.get(uri)
    date = response.strip
    Rails.logger.info "[MB Download] Latest dump: #{date}"
    date
  end

  def download_archive(date, archive)
    dest = File.join(@dump_dir, archive)

    if File.exist?(dest)
      Rails.logger.info "[MB Download] #{archive} already exists, skipping download"
      return
    end

    url = "#{BASE_URL}/#{date}/#{archive}"
    partial = "#{dest}.partial"

    Rails.logger.info "[MB Download] Downloading #{url}..."

    download_uri(URI(url), partial, archive)

    FileUtils.mv(partial, dest)
    Rails.logger.info "[MB Download] #{archive} download complete"
  end

  def download_uri(uri, partial, archive, redirects = 0)
    raise "Too many redirects for #{archive}" if redirects > 5

    Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https") do |http|
      request = Net::HTTP::Get.new(uri)
      request["User-Agent"] = "GoodSongsAPI/1.0 (musicbrainz-import)"

      http.request(request) do |response|
        case response
        when Net::HTTPRedirection
          redirect_uri = URI(response["location"])
          Rails.logger.info "[MB Download] Following redirect to #{redirect_uri.host}..."
          return download_uri(redirect_uri, partial, archive, redirects + 1)
        when Net::HTTPSuccess
          write_stream(response, partial, archive)
        else
          raise "Failed to download #{archive}: HTTP #{response.code} #{response.message}"
        end
      end
    end
  end

  def write_stream(response, partial, archive)
    total = response["Content-Length"]&.to_i
    downloaded = 0
    last_logged = 0

    File.open(partial, "wb") do |file|
      response.read_body do |chunk|
        file.write(chunk)
        downloaded += chunk.bytesize

        if total && total > 0
          pct = (downloaded * 100.0 / total).round(1)
          if pct - last_logged >= 5
            Rails.logger.info "[MB Download] #{archive}: #{pct}% (#{(downloaded / 1_048_576.0).round(1)} MB)"
            last_logged = pct
          end
        end
      end
    end
  end

  # Mapping from archive member paths to desired local filenames
  # Most files are mbdump/<table> -> <table>, but cover art uses a dotted name
  MEMBER_RENAMES = {
    "cover_art_archive.cover_art" => "cover_art"
  }.freeze

  def extract_members(archive, members)
    archive_path = File.join(@dump_dir, archive)

    unless File.exist?(archive_path)
      raise "Archive not found: #{archive_path}"
    end

    # Check which members still need extraction
    needed = members.select do |member|
      extracted_name = member.split("/").last
      local_name = MEMBER_RENAMES.fetch(extracted_name, extracted_name)
      !File.exist?(File.join(@dump_dir, local_name))
    end

    if needed.empty?
      Rails.logger.info "[MB Download] All tables from #{archive} already extracted, skipping"
      return
    end

    Rails.logger.info "[MB Download] Extracting #{needed.size} tables from #{archive}..."

    # Extract only needed members from the tar.bz2
    system("tar", "-xjf", archive_path, "-C", @dump_dir, "--strip-components=1", *needed) ||
      raise("Failed to extract from #{archive}")

    # Rename files that need it (e.g., cover_art_archive.cover_art -> cover_art)
    MEMBER_RENAMES.each do |from, to|
      src = File.join(@dump_dir, from)
      dst = File.join(@dump_dir, to)
      FileUtils.mv(src, dst) if File.exist?(src) && !File.exist?(dst)
    end

    Rails.logger.info "[MB Download] Extraction of #{archive} complete"
  end
end
