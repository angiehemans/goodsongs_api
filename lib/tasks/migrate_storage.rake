namespace :storage do
  desc "Migrate Active Storage blobs from local disk to the configured (remote) service"
  task migrate: :environment do
    require "aws-sdk-s3"

    remote_service_name = :digitalocean
    remote_service = ActiveStorage::Blob.services.fetch(remote_service_name)
    local_service = ActiveStorage::Blob.services.fetch(:local)

    total = ActiveStorage::Blob.count
    migrated = 0
    skipped = 0
    failed = 0

    puts "Migrating #{total} blobs from local disk to #{remote_service_name}..."

    ActiveStorage::Blob.find_each do |blob|
      if remote_service.exist?(blob.key)
        skipped += 1
        next
      end

      unless local_service.exist?(blob.key)
        puts "  SKIP blob #{blob.id} (#{blob.filename}) — not found on local disk"
        skipped += 1
        next
      end

      begin
        local_service.open(blob.key, checksum: blob.checksum) do |file|
          remote_service.upload(blob.key, file, checksum: blob.checksum,
            content_type: blob.content_type)
        end
        migrated += 1
        print "."
      rescue => e
        failed += 1
        puts "\n  ERROR blob #{blob.id} (#{blob.filename}): #{e.message}"
      end

      if (migrated + failed) % 100 == 0
        puts "\n  Progress: #{migrated + skipped + failed}/#{total} (#{migrated} uploaded, #{skipped} skipped, #{failed} failed)"
      end
    end

    puts "\nDone! Uploaded: #{migrated}, Skipped: #{skipped}, Failed: #{failed}, Total: #{total}"
  end

  desc "Verify all Active Storage blobs exist on the remote service"
  task verify: :environment do
    require "aws-sdk-s3"

    remote_service = ActiveStorage::Blob.services.fetch(:digitalocean)
    missing = []

    ActiveStorage::Blob.find_each do |blob|
      unless remote_service.exist?(blob.key)
        missing << { id: blob.id, filename: blob.filename.to_s, key: blob.key }
      end
    end

    if missing.empty?
      puts "All #{ActiveStorage::Blob.count} blobs exist on remote storage."
    else
      puts "#{missing.size} blobs missing from remote storage:"
      missing.each { |b| puts "  Blob #{b[:id]}: #{b[:filename]} (key: #{b[:key]})" }
    end
  end
end
