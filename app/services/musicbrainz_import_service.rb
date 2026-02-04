# frozen_string_literal: true

require "pg"

class MusicbrainzImportService
  STAGING_SCHEMA = "musicbrainz_staging"

  # MusicBrainz dump column definitions for each table.
  # Column order must match the TSV dump files exactly for COPY to work.
  STAGING_TABLES = {
    artist: "id INTEGER, gid TEXT, name TEXT, sort_name TEXT, begin_date_year INTEGER, begin_date_month INTEGER, begin_date_day INTEGER, end_date_year INTEGER, end_date_month INTEGER, end_date_day INTEGER, type INTEGER, area INTEGER, gender INTEGER, comment TEXT, edits_pending INTEGER, last_updated TEXT, ended BOOLEAN, begin_area INTEGER, end_area INTEGER",
    artist_alias: "id INTEGER, artist INTEGER, name TEXT, locale TEXT, edits_pending INTEGER, last_updated TEXT, type INTEGER, sort_name TEXT, begin_date_year INTEGER, begin_date_month INTEGER, begin_date_day INTEGER, end_date_year INTEGER, end_date_month INTEGER, end_date_day INTEGER, primary_for_locale BOOLEAN, ended BOOLEAN",
    artist_credit: "id INTEGER, name TEXT, artist_count INTEGER, ref_count INTEGER, created TEXT, edits_pending INTEGER, gid TEXT",
    artist_credit_name: "artist_credit INTEGER, position INTEGER, artist INTEGER, name TEXT, join_phrase TEXT",
    recording: "id INTEGER, gid TEXT, name TEXT, artist_credit INTEGER, length INTEGER, comment TEXT, edits_pending INTEGER, last_updated TEXT, video BOOLEAN",
    isrc: "id INTEGER, recording INTEGER, isrc TEXT, source INTEGER, edits_pending INTEGER, created TEXT",
    release_group: "id INTEGER, gid TEXT, name TEXT, artist_credit INTEGER, type INTEGER, comment TEXT, edits_pending INTEGER, last_updated TEXT",
    release: "id INTEGER, gid TEXT, name TEXT, artist_credit INTEGER, release_group INTEGER, status INTEGER, packaging INTEGER, language INTEGER, script INTEGER, barcode TEXT, comment TEXT, edits_pending INTEGER, quality INTEGER, last_updated TEXT",
    medium: "id INTEGER, release INTEGER, position INTEGER, format INTEGER, name TEXT, edits_pending INTEGER, last_updated TEXT, track_count INTEGER, gid TEXT",
    track: "id INTEGER, gid TEXT, recording INTEGER, medium INTEGER, position INTEGER, number TEXT, name TEXT, artist_credit INTEGER, length INTEGER, edits_pending INTEGER, last_updated TEXT, is_data_track BOOLEAN",
    release_country: "release INTEGER, country INTEGER, date_year INTEGER, date_month INTEGER, date_day INTEGER",
    area: "id INTEGER, gid TEXT, name TEXT, type INTEGER, edits_pending INTEGER, last_updated TEXT, begin_date_year INTEGER, begin_date_month INTEGER, begin_date_day INTEGER, end_date_year INTEGER, end_date_month INTEGER, end_date_day INTEGER, ended BOOLEAN, comment TEXT",
    iso_3166_1: "area INTEGER, code TEXT",
    tag: "id INTEGER, name TEXT, ref_count INTEGER",
    artist_tag: "artist INTEGER, tag INTEGER, count INTEGER, last_updated TEXT",
    artist_type: "id INTEGER, name TEXT, parent INTEGER, child_order INTEGER, description TEXT, gid TEXT",
    release_group_primary_type: "id INTEGER, name TEXT, parent INTEGER, child_order INTEGER, description TEXT, gid TEXT",
    release_status: "id INTEGER, name TEXT, parent INTEGER, child_order INTEGER, description TEXT, gid TEXT",
    cover_art: "id BIGINT, release INTEGER, comment TEXT, edit INTEGER, ordering INTEGER, created TEXT, approved INTEGER, mime_type TEXT, filesize INTEGER, thumb_250_filesize INTEGER, thumb_500_filesize INTEGER, thumb_1200_filesize INTEGER"
  }.freeze

  # Indexes to create after COPY loading (not before — much faster)
  STAGING_INDEXES = [
    "CREATE INDEX idx_stg_artist_id ON #{STAGING_SCHEMA}.artist (id)",
    "CREATE INDEX idx_stg_artist_type ON #{STAGING_SCHEMA}.artist (type)",
    "CREATE INDEX idx_stg_artist_area ON #{STAGING_SCHEMA}.artist (area)",
    "CREATE INDEX idx_stg_artist_alias_artist ON #{STAGING_SCHEMA}.artist_alias (artist)",
    "CREATE INDEX idx_stg_acn_artist_credit ON #{STAGING_SCHEMA}.artist_credit_name (artist_credit)",
    "CREATE INDEX idx_stg_acn_artist ON #{STAGING_SCHEMA}.artist_credit_name (artist)",
    "CREATE INDEX idx_stg_recording_id ON #{STAGING_SCHEMA}.recording (id)",
    "CREATE INDEX idx_stg_recording_ac ON #{STAGING_SCHEMA}.recording (artist_credit)",
    "CREATE INDEX idx_stg_isrc_recording ON #{STAGING_SCHEMA}.isrc (recording)",
    "CREATE INDEX idx_stg_release_group_id ON #{STAGING_SCHEMA}.release_group (id)",
    "CREATE INDEX idx_stg_release_group_type ON #{STAGING_SCHEMA}.release_group (type)",
    "CREATE INDEX idx_stg_release_id ON #{STAGING_SCHEMA}.release (id)",
    "CREATE INDEX idx_stg_release_rg ON #{STAGING_SCHEMA}.release (release_group)",
    "CREATE INDEX idx_stg_release_status ON #{STAGING_SCHEMA}.release (status)",
    "CREATE INDEX idx_stg_medium_release ON #{STAGING_SCHEMA}.medium (release)",
    "CREATE INDEX idx_stg_medium_id ON #{STAGING_SCHEMA}.medium (id)",
    "CREATE INDEX idx_stg_track_medium ON #{STAGING_SCHEMA}.track (medium)",
    "CREATE INDEX idx_stg_track_recording ON #{STAGING_SCHEMA}.track (recording)",
    "CREATE INDEX idx_stg_release_country_release ON #{STAGING_SCHEMA}.release_country (release)",
    "CREATE INDEX idx_stg_release_country_country ON #{STAGING_SCHEMA}.release_country (country)",
    "CREATE INDEX idx_stg_area_id ON #{STAGING_SCHEMA}.area (id)",
    "CREATE INDEX idx_stg_iso_area ON #{STAGING_SCHEMA}.iso_3166_1 (area)",
    "CREATE INDEX idx_stg_tag_id ON #{STAGING_SCHEMA}.tag (id)",
    "CREATE INDEX idx_stg_artist_tag_artist ON #{STAGING_SCHEMA}.artist_tag (artist)",
    "CREATE INDEX idx_stg_artist_tag_tag ON #{STAGING_SCHEMA}.artist_tag (tag)",
    "CREATE INDEX idx_stg_artist_type_id ON #{STAGING_SCHEMA}.artist_type (id)",
    "CREATE INDEX idx_stg_rgpt_id ON #{STAGING_SCHEMA}.release_group_primary_type (id)",
    "CREATE INDEX idx_stg_release_status_id ON #{STAGING_SCHEMA}.release_status (id)",
    "CREATE INDEX idx_stg_cover_art_release ON #{STAGING_SCHEMA}.cover_art (release)"
  ].freeze

  def initialize(dump_dir: nil, limit: nil, batch_size: 5000)
    @dump_dir = dump_dir || Rails.root.join("tmp", "musicbrainz").to_s
    @limit = limit
    @batch_size = batch_size
  end

  # Step 1: Create staging schema and load TSV data
  def load_staging
    create_staging_schema
    copy_data_to_staging
    create_staging_indexes
  end

  # Step 2: ETL from staging into app tables
  def import
    build_qualifying_artists
    import_bands
    build_qualifying_releases
    import_albums
    import_tracks
    import_band_aliases
    Rails.logger.info "[MB Import] Import complete"
  end

  # Cleanup: drop the staging schema
  def drop_staging
    execute("DROP SCHEMA IF EXISTS #{STAGING_SCHEMA} CASCADE")
    execute("DROP TABLE IF EXISTS mb_qualifying_artists")
    execute("DROP TABLE IF EXISTS mb_qualifying_releases")
    Rails.logger.info "[MB Import] Staging schema dropped"
  end

  private

  def connection
    ActiveRecord::Base.connection
  end

  def execute(sql)
    connection.execute(sql)
  end

  def raw_connection
    connection.raw_connection
  end

  # --- Staging Schema ---

  def create_staging_schema
    Rails.logger.info "[MB Import] Creating staging schema..."
    execute("DROP SCHEMA IF EXISTS #{STAGING_SCHEMA} CASCADE")
    execute("CREATE SCHEMA #{STAGING_SCHEMA}")

    STAGING_TABLES.each do |table, columns|
      execute("CREATE TABLE #{STAGING_SCHEMA}.#{table} (#{columns})")
    end

    Rails.logger.info "[MB Import] Staging schema created with #{STAGING_TABLES.size} tables"
  end

  def copy_data_to_staging
    STAGING_TABLES.each_key do |table|
      file_path = File.join(@dump_dir, table.to_s)

      unless File.exist?(file_path)
        Rails.logger.warn "[MB Import] File not found, skipping: #{file_path}"
        next
      end

      file_size = (File.size(file_path) / 1_048_576.0).round(1)
      Rails.logger.info "[MB Import] Loading #{table} (#{file_size} MB)..."

      columns = STAGING_TABLES[table].scan(/\w+\s+\w+/).map { |col| col.split.first }
      col_list = columns.join(", ")

      conn = raw_connection
      lines = 0

      conn.copy_data("COPY #{STAGING_SCHEMA}.#{table} (#{col_list}) FROM STDIN") do
        File.foreach(file_path) do |line|
          conn.put_copy_data(line)
          lines += 1
          if lines % 1_000_000 == 0
            Rails.logger.info "[MB Import]   #{table}: #{lines} rows loaded..."
          end
        end
      end

      Rails.logger.info "[MB Import] #{table}: #{lines} rows loaded"
    end
  end

  def create_staging_indexes
    Rails.logger.info "[MB Import] Creating staging indexes..."

    STAGING_INDEXES.each do |idx_sql|
      execute(idx_sql)
    end

    Rails.logger.info "[MB Import] #{STAGING_INDEXES.size} indexes created"
  end

  # --- ETL: Qualifying Artists ---

  def build_qualifying_artists
    Rails.logger.info "[MB Import] Building qualifying artists list..."

    execute("DROP TABLE IF EXISTS mb_qualifying_artists")

    limit_clause = @limit ? "LIMIT #{@limit.to_i}" : ""

    execute(<<~SQL)
      CREATE TEMP TABLE mb_qualifying_artists AS
      SELECT DISTINCT acn.artist AS mb_artist_id
      FROM #{STAGING_SCHEMA}.artist_credit_name acn
      JOIN #{STAGING_SCHEMA}.recording r ON r.artist_credit = acn.artist_credit
      JOIN #{STAGING_SCHEMA}.isrc i ON i.recording = r.id
      #{limit_clause}
    SQL

    execute("CREATE INDEX idx_mqa_id ON mb_qualifying_artists (mb_artist_id)")

    count = execute("SELECT COUNT(*) FROM mb_qualifying_artists").first["count"]
    Rails.logger.info "[MB Import] #{count} qualifying artists found"
  end

  # --- ETL: Import Bands ---

  def import_bands
    total = execute("SELECT COUNT(*) FROM mb_qualifying_artists").first["count"].to_i
    Rails.logger.info "[MB Import] Importing bands (#{total} total)..."

    offset = 0
    imported = 0

    while offset < total
      batch_end = [offset + @batch_size, total].min
      Rails.logger.info "[MB Import] Importing bands #{offset + 1}-#{batch_end} of #{total}"

      begin
        execute(<<~SQL)
          INSERT INTO bands (
            name, sort_name, musicbrainz_id, country, artist_type, genres,
            slug, source, verified, created_at, updated_at
          )
          SELECT
            a.name,
            a.sort_name,
            a.gid,
            iso.code,
            at.name,
            COALESCE(
              (SELECT jsonb_agg(t.name ORDER BY atg.count DESC)
               FROM #{STAGING_SCHEMA}.artist_tag atg
               JOIN #{STAGING_SCHEMA}.tag t ON t.id = atg.tag
               WHERE atg.artist = a.id
               LIMIT 10),
              '[]'::jsonb
            ),
            CONCAT(
              LOWER(REGEXP_REPLACE(REGEXP_REPLACE(a.name, '[^a-zA-Z0-9\\-_ ]', '', 'g'), '\\s+', '-', 'g')),
              '-mb', a.id
            ),
            0,
            true,
            NOW(),
            NOW()
          FROM #{STAGING_SCHEMA}.artist a
          JOIN mb_qualifying_artists mqa ON mqa.mb_artist_id = a.id
          LEFT JOIN #{STAGING_SCHEMA}.artist_type at ON at.id = a.type
          LEFT JOIN #{STAGING_SCHEMA}.area ar ON ar.id = a.area
          LEFT JOIN #{STAGING_SCHEMA}.iso_3166_1 iso ON iso.area = ar.id
          ORDER BY a.id
          OFFSET #{offset} LIMIT #{@batch_size}
          ON CONFLICT (musicbrainz_id) DO UPDATE SET
            name = EXCLUDED.name,
            sort_name = EXCLUDED.sort_name,
            country = EXCLUDED.country,
            artist_type = EXCLUDED.artist_type,
            genres = EXCLUDED.genres,
            verified = true,
            updated_at = NOW()
          WHERE bands.source = 0
        SQL

        imported += @batch_size
      rescue => e
        Rails.logger.error "[MB Import] Error importing bands batch #{offset + 1}-#{batch_end}: #{e.message}"
      end

      offset += @batch_size
    end

    final_count = Band.where(source: :musicbrainz, verified: true).count
    Rails.logger.info "[MB Import] Bands import complete: #{final_count} total musicbrainz bands"
  end

  # --- ETL: Qualifying Releases ---

  def build_qualifying_releases
    Rails.logger.info "[MB Import] Building qualifying releases list..."

    execute("DROP TABLE IF EXISTS mb_qualifying_releases")

    execute(<<~SQL)
      CREATE TEMP TABLE mb_qualifying_releases AS
      SELECT DISTINCT r.id AS mb_release_id
      FROM #{STAGING_SCHEMA}.release r
      JOIN #{STAGING_SCHEMA}.artist_credit_name acn ON acn.artist_credit = r.artist_credit
      JOIN mb_qualifying_artists mqa ON mqa.mb_artist_id = acn.artist
      JOIN #{STAGING_SCHEMA}.cover_art ca ON ca.release = r.id
    SQL

    execute("CREATE INDEX idx_mqr_id ON mb_qualifying_releases (mb_release_id)")

    count = execute("SELECT COUNT(*) FROM mb_qualifying_releases").first["count"]
    Rails.logger.info "[MB Import] #{count} qualifying releases found"
  end

  # --- ETL: Import Albums ---

  def import_albums
    total = execute("SELECT COUNT(*) FROM mb_qualifying_releases").first["count"].to_i
    Rails.logger.info "[MB Import] Importing albums (#{total} total)..."

    offset = 0

    while offset < total
      batch_end = [offset + @batch_size, total].min
      Rails.logger.info "[MB Import] Importing albums #{offset + 1}-#{batch_end} of #{total}"

      begin
        execute(<<~SQL)
          INSERT INTO albums (
            id, name, band_id, musicbrainz_release_id, cover_art_url,
            release_date, release_type, country, source, verified,
            created_at, updated_at
          )
          SELECT
            gen_random_uuid(),
            sub.name,
            sub.band_id,
            sub.gid,
            sub.cover_art_url,
            sub.release_date,
            sub.release_type,
            sub.country,
            0,
            true,
            NOW(),
            NOW()
          FROM (
            SELECT DISTINCT ON (r.gid)
              r.gid,
              r.name,
              b.id AS band_id,
              CONCAT('https://coverartarchive.org/release/', r.gid, '/front-500') AS cover_art_url,
              CASE
                WHEN rc.date_year IS NOT NULL THEN
                  MAKE_DATE(
                    rc.date_year,
                    COALESCE(NULLIF(rc.date_month, 0), 1),
                    COALESCE(NULLIF(rc.date_day, 0), 1)
                  )
                ELSE NULL
              END AS release_date,
              CASE LOWER(COALESCE(rgpt.name, 'other'))
                WHEN 'album' THEN 'album'
                WHEN 'single' THEN 'single'
                WHEN 'ep' THEN 'ep'
                WHEN 'compilation' THEN 'compilation'
                WHEN 'live' THEN 'live'
                WHEN 'remix' THEN 'remix'
                WHEN 'soundtrack' THEN 'soundtrack'
                ELSE 'other'
              END AS release_type,
              iso.code AS country,
              r.id AS release_id
            FROM #{STAGING_SCHEMA}.release r
            JOIN mb_qualifying_releases mqr ON mqr.mb_release_id = r.id
            JOIN #{STAGING_SCHEMA}.artist_credit_name acn ON acn.artist_credit = r.artist_credit AND acn.position = 0
            JOIN bands b ON b.musicbrainz_id = (
              SELECT a.gid FROM #{STAGING_SCHEMA}.artist a WHERE a.id = acn.artist
            )
            LEFT JOIN #{STAGING_SCHEMA}.release_group rg ON rg.id = r.release_group
            LEFT JOIN #{STAGING_SCHEMA}.release_group_primary_type rgpt ON rgpt.id = rg.type
            LEFT JOIN #{STAGING_SCHEMA}.release_country rc ON rc.release = r.id
            LEFT JOIN #{STAGING_SCHEMA}.area ar ON ar.id = rc.country
            LEFT JOIN #{STAGING_SCHEMA}.iso_3166_1 iso ON iso.area = ar.id
            ORDER BY r.gid, rc.date_year NULLS LAST
          ) sub
          ORDER BY sub.release_id
          OFFSET #{offset} LIMIT #{@batch_size}
          ON CONFLICT (musicbrainz_release_id) DO UPDATE SET
            name = EXCLUDED.name,
            band_id = EXCLUDED.band_id,
            cover_art_url = EXCLUDED.cover_art_url,
            release_date = EXCLUDED.release_date,
            release_type = EXCLUDED.release_type,
            country = EXCLUDED.country,
            verified = true,
            updated_at = NOW()
          WHERE albums.source = 0
        SQL
      rescue => e
        Rails.logger.error "[MB Import] Error importing albums batch #{offset + 1}-#{batch_end}: #{e.message}"
      end

      offset += @batch_size
    end

    final_count = Album.where(source: :musicbrainz, verified: true).count
    Rails.logger.info "[MB Import] Albums import complete: #{final_count} total musicbrainz albums"
  end

  # --- ETL: Import Tracks ---

  def import_tracks
    # Count tracks from qualifying releases
    total = execute(<<~SQL).first["count"].to_i
      SELECT COUNT(*) FROM (
        SELECT DISTINCT ON (rec.gid) rec.gid
        FROM #{STAGING_SCHEMA}.track t
        JOIN #{STAGING_SCHEMA}.medium m ON m.id = t.medium
        JOIN #{STAGING_SCHEMA}.recording rec ON rec.id = t.recording
        JOIN mb_qualifying_releases mqr ON mqr.mb_release_id = m.release
        JOIN #{STAGING_SCHEMA}.release r ON r.id = m.release
        JOIN albums alb ON alb.musicbrainz_release_id = r.gid
        WHERE t.is_data_track IS NOT TRUE
        ORDER BY rec.gid, t.id
      ) distinct_tracks
    SQL

    Rails.logger.info "[MB Import] Importing tracks (#{total} total)..."

    offset = 0

    while offset < total
      batch_end = [offset + @batch_size, total].min
      Rails.logger.info "[MB Import] Importing tracks #{offset + 1}-#{batch_end} of #{total}"

      begin
        execute(<<~SQL)
          INSERT INTO tracks (
            id, name, band_id, album_id, duration_ms,
            track_number, disc_number, musicbrainz_recording_id, isrc,
            source, verified, created_at, updated_at
          )
          SELECT
            gen_random_uuid(),
            sub.name,
            sub.band_id,
            sub.album_id,
            sub.duration_ms,
            sub.track_number,
            sub.disc_number,
            sub.recording_gid,
            sub.isrc,
            0,
            true,
            NOW(),
            NOW()
          FROM (
            SELECT DISTINCT ON (rec.gid)
              t.name,
              alb.band_id,
              alb.id AS album_id,
              rec.length AS duration_ms,
              t.position AS track_number,
              m.position AS disc_number,
              rec.gid AS recording_gid,
              (SELECT i.isrc FROM #{STAGING_SCHEMA}.isrc i WHERE i.recording = rec.id LIMIT 1) AS isrc,
              t.id AS track_id
            FROM #{STAGING_SCHEMA}.track t
            JOIN #{STAGING_SCHEMA}.medium m ON m.id = t.medium
            JOIN #{STAGING_SCHEMA}.recording rec ON rec.id = t.recording
            JOIN mb_qualifying_releases mqr ON mqr.mb_release_id = m.release
            JOIN #{STAGING_SCHEMA}.release r ON r.id = m.release
            JOIN albums alb ON alb.musicbrainz_release_id = r.gid
            WHERE t.is_data_track IS NOT TRUE
            ORDER BY rec.gid, t.id
          ) sub
          ORDER BY sub.track_id
          OFFSET #{offset} LIMIT #{@batch_size}
          ON CONFLICT (musicbrainz_recording_id) DO UPDATE SET
            name = EXCLUDED.name,
            band_id = EXCLUDED.band_id,
            album_id = EXCLUDED.album_id,
            duration_ms = EXCLUDED.duration_ms,
            track_number = EXCLUDED.track_number,
            disc_number = EXCLUDED.disc_number,
            isrc = EXCLUDED.isrc,
            verified = true,
            updated_at = NOW()
          WHERE tracks.source = 0
        SQL
      rescue => e
        Rails.logger.error "[MB Import] Error importing tracks batch #{offset + 1}-#{batch_end}: #{e.message}"
      end

      offset += @batch_size
    end

    final_count = Track.where(source: :musicbrainz, verified: true).count
    Rails.logger.info "[MB Import] Tracks import complete: #{final_count} total musicbrainz tracks"
  end

  # --- ETL: Import Band Aliases ---

  def import_band_aliases
    total = execute(<<~SQL).first["count"].to_i
      SELECT COUNT(*)
      FROM #{STAGING_SCHEMA}.artist_alias aa
      JOIN mb_qualifying_artists mqa ON mqa.mb_artist_id = aa.artist
    SQL

    Rails.logger.info "[MB Import] Importing band aliases (#{total} total)..."

    offset = 0

    while offset < total
      batch_end = [offset + @batch_size, total].min
      Rails.logger.info "[MB Import] Importing band aliases #{offset + 1}-#{batch_end} of #{total}"

      begin
        execute(<<~SQL)
          INSERT INTO band_aliases (id, band_id, name, locale, created_at)
          SELECT
            gen_random_uuid(),
            b.id,
            aa.name,
            aa.locale,
            NOW()
          FROM #{STAGING_SCHEMA}.artist_alias aa
          JOIN #{STAGING_SCHEMA}.artist a ON a.id = aa.artist
          JOIN mb_qualifying_artists mqa ON mqa.mb_artist_id = aa.artist
          JOIN bands b ON b.musicbrainz_id = a.gid
          ORDER BY aa.id
          OFFSET #{offset} LIMIT #{@batch_size}
          ON CONFLICT DO NOTHING
        SQL
      rescue => e
        Rails.logger.error "[MB Import] Error importing band aliases batch #{offset + 1}-#{batch_end}: #{e.message}"
      end

      offset += @batch_size
    end

    final_count = BandAlias.count
    Rails.logger.info "[MB Import] Band aliases import complete: #{final_count} total"
  end
end
