# frozen_string_literal: true

namespace :musicbrainz do
  desc "Download MusicBrainz dump archives"
  task download: :environment do
    dump_dir = ENV.fetch("DUMP_DIR", Rails.root.join("tmp", "musicbrainz").to_s)
    dump_date = ENV.fetch("DUMP_DATE", "latest")

    MusicbrainzDownloadService.new(dump_dir: dump_dir, dump_date: dump_date).call
  end

  desc "Create staging schema and load MusicBrainz TSV data"
  task load_staging: :environment do
    dump_dir = ENV.fetch("DUMP_DIR", Rails.root.join("tmp", "musicbrainz").to_s)

    service = MusicbrainzImportService.new(dump_dir: dump_dir)
    service.load_staging
  end

  desc "ETL: import from staging into bands, albums, tracks, band_aliases"
  task import: :environment do
    dump_dir = ENV.fetch("DUMP_DIR", Rails.root.join("tmp", "musicbrainz").to_s)
    limit = ENV["LIMIT"]&.to_i
    batch_size = ENV.fetch("BATCH", 5000).to_i

    service = MusicbrainzImportService.new(dump_dir: dump_dir, limit: limit, batch_size: batch_size)
    service.import
  end

  desc "Drop the musicbrainz_staging schema"
  task drop_staging: :environment do
    MusicbrainzImportService.new.drop_staging
  end

  desc "Full import pipeline: download, load staging, import, drop staging"
  task full_import: :environment do
    dump_dir = ENV.fetch("DUMP_DIR", Rails.root.join("tmp", "musicbrainz").to_s)
    dump_date = ENV.fetch("DUMP_DATE", "latest")
    limit = ENV["LIMIT"]&.to_i
    batch_size = ENV.fetch("BATCH", 5000).to_i

    puts "[MB Full Import] Starting full MusicBrainz import pipeline..."

    puts "[MB Full Import] Step 1/4: Downloading dump archives..."
    MusicbrainzDownloadService.new(dump_dir: dump_dir, dump_date: dump_date).call

    service = MusicbrainzImportService.new(dump_dir: dump_dir, limit: limit, batch_size: batch_size)

    puts "[MB Full Import] Step 2/4: Loading staging data..."
    service.load_staging

    puts "[MB Full Import] Step 3/4: Running ETL import..."
    service.import

    puts "[MB Full Import] Step 4/4: Dropping staging schema..."
    service.drop_staging

    puts "[MB Full Import] Pipeline complete!"
  end
end
