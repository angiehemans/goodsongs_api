# GoodSongs: Image Storage Migration Guide

## Base64 DB Columns → Active Storage + Digital Ocean Spaces

---

## Overview

**Current state:** Images stored as base64 strings in DB columns  
**Target state:** Images stored in DO Spaces, served via CDN, referenced via Active Storage

**Why this matters:**

- Base64 inflates image size by ~33%
- Large text columns slow down every query on those tables, even ones that don't need the image
- Your DB is doing work it shouldn't — storing and serving binary data
- Serving base64 over the API means massive JSON payloads on every image load

**What you'll end up with:**

- Images stored cheaply in DO Spaces (~$5/mo for 250GB + CDN)
- Fast CDN-served URLs instead of inline base64
- Active Storage managing all references cleanly
- Your DB tables slim and fast again

**Environment note:** This guide covers local development and production only. Nothing changes in your local setup — development continues to use the local disk service. Only production uses Spaces.

---

## Phase 1: Set Up Digital Ocean Spaces

### Step 1: Create the Spaces Bucket

1. Log in to Digital Ocean → **Spaces Object Storage** → **Create a Space**
2. Choose the same datacenter region as your droplet (e.g., `nyc3`)
3. Name it something like `goodsongs-production`
4. Set **File Listing** to "Restrict File Listing"
5. Click **Create a Space**

### Step 2: Enable the CDN

1. Inside your Space → **Settings** tab → **CDN** section
2. Click **Enable CDN**
3. Note your CDN endpoint — it will look like:  
   `https://goodsongs-production.nyc3.cdn.digitaloceanspaces.com`

### Step 3: Generate Spaces Access Keys

1. Digital Ocean → **API** → **Spaces Keys** → **Generate New Key**
2. Name it `goodsongs-rails`
3. Copy the **Access Key** and **Secret Key** — you only see the secret once

Add these to your production environment variables on your droplet:

```bash
SPACES_ACCESS_KEY=your_access_key_here
SPACES_SECRET_KEY=your_secret_key_here
SPACES_BUCKET=goodsongs-production
SPACES_REGION=nyc3
SPACES_ENDPOINT=https://nyc3.digitaloceanspaces.com
SPACES_CDN_HOST=goodsongs-production.nyc3.cdn.digitaloceanspaces.com
```

You do not need these in your local `.env` — local dev never talks to Spaces.

---

## Phase 2: Configure Active Storage

### Step 4: Add the AWS gem

DO Spaces is S3-compatible, so you use the AWS S3 gem:

```ruby
# Gemfile
gem "aws-sdk-s3", require: false
```

```bash
bundle install
```

### Step 5: Configure storage.yml

```yaml
# config/storage.yml

local:
  service: Disk
  root: <%= Rails.root.join("storage") %>

digitalocean:
  service: S3
  access_key_id: <%= ENV["SPACES_ACCESS_KEY"] %>
  secret_access_key: <%= ENV["SPACES_SECRET_KEY"] %>
  endpoint: <%= ENV["SPACES_ENDPOINT"] %>
  region: <%= ENV["SPACES_REGION"] %>
  bucket: <%= ENV["SPACES_BUCKET"] %>
  force_path_style: false
```

### Step 6: Point each environment to the right service

```ruby
# config/environments/development.rb
config.active_storage.service = :local
```

```ruby
# config/environments/production.rb
config.active_storage.service = :digitalocean
```

Development stays on local disk. No other code changes are needed — Active Storage abstracts the backend entirely.

### Step 7: Set default URL options

Active Storage needs a host to generate full URLs. Make sure this is set in both environments:

```ruby
# config/environments/development.rb
Rails.application.routes.default_url_options = { host: "localhost", port: 3000 }
```

```ruby
# config/environments/production.rb
Rails.application.routes.default_url_options = { host: "your-production-domain.com" }
```

### Step 8: Run Active Storage migrations (if not already done)

```bash
bin/rails active_storage:install
bin/rails db:migrate
```

This creates the `active_storage_blobs`, `active_storage_attachments`, and `active_storage_variant_records` tables.

---

## Phase 3: Add Active Storage to Your Models

Add `has_one_attached` (or `has_many_attached`) to every model that currently has a base64 image column:

```ruby
# app/models/band.rb
class Band < ApplicationRecord
  has_one_attached :avatar
  has_one_attached :header_image
end

# app/models/user.rb
class User < ApplicationRecord
  has_one_attached :avatar
end

# app/models/album.rb (if applicable)
class Album < ApplicationRecord
  has_one_attached :cover_art
end
```

Use `has_many_attached` if a model supports multiple images:

```ruby
has_many_attached :gallery_images
```

---

## Phase 4: Write and Test the Migration Rake Task Locally

Before touching production, write and validate the rake task locally. Your local images are probably sparse or different from production — that's fine. What you're confirming is that the task runs cleanly, decodes correctly, and attaches successfully.

### Step 9: Check what your base64 strings look like

In the Rails console, inspect one record before writing the task:

```ruby
Band.first.avatar_base64[0, 50]
```

If it starts with `data:image/jpeg;base64,` or similar, you need to strip that prefix before decoding. If it's raw base64, you can decode directly. The rake task below handles both cases.

### Step 10: Write the migration rake task

```ruby
# lib/tasks/migrate_images.rake

namespace :images do
  desc "Migrate base64 band avatars from DB column to Active Storage"
  task migrate_band_avatars: :environment do
    puts "Starting band avatar migration..."

    total    = Band.where.not(avatar_base64: nil).count
    migrated = 0
    failed   = 0

    Band.where.not(avatar_base64: nil).find_each do |band|
      begin
        # Strip data URI prefix if present (e.g. "data:image/jpeg;base64,...")
        raw = band.avatar_base64.sub(/\Adata:[\w\/]+;base64,/, "")
        image_data   = Base64.decode64(raw)
        content_type = detect_content_type(image_data)
        extension    = content_type.split("/").last
        filename     = "band_#{band.id}_avatar.#{extension}"

        band.avatar.attach(
          io:           StringIO.new(image_data),
          filename:     filename,
          content_type: content_type
        )

        if band.avatar.attached?
          migrated += 1
          print "."
        else
          failed += 1
          puts "\nFailed to attach for band #{band.id}"
        end

      rescue => e
        failed += 1
        puts "\nError migrating band #{band.id}: #{e.message}"
      end

      if (migrated + failed) % 50 == 0
        puts "\nProgress: #{migrated + failed}/#{total} (#{migrated} ok, #{failed} failed)"
      end
    end

    puts "\nDone! Migrated: #{migrated}, Failed: #{failed}, Total: #{total}"
  end

  desc "Migrate base64 user avatars from DB column to Active Storage"
  task migrate_user_avatars: :environment do
    puts "Starting user avatar migration..."

    total    = User.where.not(avatar_base64: nil).count
    migrated = 0
    failed   = 0

    User.where.not(avatar_base64: nil).find_each do |user|
      begin
        raw          = user.avatar_base64.sub(/\Adata:[\w\/]+;base64,/, "")
        image_data   = Base64.decode64(raw)
        content_type = detect_content_type(image_data)
        extension    = content_type.split("/").last
        filename     = "user_#{user.id}_avatar.#{extension}"

        user.avatar.attach(
          io:           StringIO.new(image_data),
          filename:     filename,
          content_type: content_type
        )

        migrated += 1 if user.avatar.attached?
      rescue => e
        failed += 1
        puts "Error migrating user #{user.id}: #{e.message}"
      end
    end

    puts "Done! Migrated: #{migrated}, Failed: #{failed}"
  end

  desc "Migrate all base64 images to Active Storage"
  task all: [:migrate_band_avatars, :migrate_user_avatars] do
    puts "All image migrations complete."
  end

  def detect_content_type(data)
    if data[0, 8] == "\x89PNG\r\n\x1a\n"
      "image/png"
    elsif data[0, 3] == "\xFF\xD8\xFF"
      "image/jpeg"
    elsif data[0, 6] == "GIF87a" || data[0, 6] == "GIF89a"
      "image/gif"
    elsif data[0, 4] == "RIFF" && data[8, 4] == "WEBP"
      "image/webp"
    else
      "image/jpeg"
    end
  end
end
```

### Step 11: Run locally and verify

```bash
RAILS_ENV=development bundle exec rails images:migrate_band_avatars
```

Then verify in the Rails console:

```ruby
Band.first.avatar.attached?   # => true
Band.first.avatar.url         # => local Active Storage URL
```

If that looks good, you're ready for production.

---

## Phase 5: Run the Migration in Production

### Step 12: Back up your production database first

This is your safety net. The rake task does not delete or modify the base64 columns — your original data stays intact until you explicitly drop those columns in Phase 7. But a backup before any production migration is non-negotiable.

**If you're using Digital Ocean Managed Postgres:**  
Take a manual snapshot from the DO dashboard before proceeding.

**If you're running Postgres directly on your droplet:**

```bash
pg_dump -U your_db_user goodsongs_production > goodsongs_backup_$(date +%Y%m%d).sql
```

### Step 13: Run the migration in production

SSH into your droplet and run:

```bash
RAILS_ENV=production bundle exec rails images:all
```

Run this during low-traffic hours. For large datasets, consider running each task separately so you can monitor progress between them.

### Step 14: Verify in production

Check a handful of records in the production Rails console:

```ruby
Band.first.avatar.attached?   # => true
Band.first.avatar.url         # => CDN URL
Band.last.avatar.attached?    # => true
```

Spot-check a few URLs in a browser to confirm images are actually loading from the CDN.

---

## Phase 6: Update Your API and Clients

### Step 15: Update serializers to return URLs instead of base64

Before:

```ruby
# app/serializers/band_serializer.rb
class BandSerializer < ActiveModel::Serializer
  attributes :id, :name, :avatar_base64
end
```

After:

```ruby
# app/serializers/band_serializer.rb
class BandSerializer < ActiveModel::Serializer
  attributes :id, :name, :avatar_url

  def avatar_url
    return nil unless object.avatar.attached?
    object.avatar.url
  end
end
```

If you want to expose multiple sizes:

```ruby
def avatar_url
  return nil unless object.avatar.attached?
  {
    original: object.avatar.url,
    thumb:    url_for(object.avatar.variant(resize_to_fill: [80, 80])),
    medium:   url_for(object.avatar.variant(resize_to_fill: [300, 300]))
  }
end
```

> Variants require `vips` on your droplet:
>
> ```bash
> sudo apt-get install libvips
> ```
>
> Then in `config/application.rb`:
>
> ```ruby
> config.active_storage.variant_processor = :vips
> ```

### Step 16: Update the Android app

Before:

```kotlin
val bytes = Base64.decode(band.avatarBase64, Base64.DEFAULT)
val bitmap = BitmapFactory.decodeByteArray(bytes, 0, bytes.size)
imageView.setImageBitmap(bitmap)
```

After — just load the URL with Glide or Coil:

```kotlin
Glide.with(context)
    .load(band.avatarUrl)
    .placeholder(R.drawable.placeholder_avatar)
    .into(imageView)
```

**Android emulator note:** The emulator can't reach `localhost`. When testing locally, use your machine's actual local IP instead of `localhost` in your API base URL, and make sure your `default_url_options` host matches. You can manage this with an env var:

```ruby
# config/environments/development.rb
Rails.application.routes.default_url_options = {
  host: ENV.fetch("LOCAL_HOST", "localhost"),
  port: 3000
}
```

Then set `LOCAL_HOST=192.168.1.x` in your `.env` when testing on the emulator.

### Step 17: Update the Next.js frontend

Before:

```tsx
<img src={`data:image/jpeg;base64,${band.avatarBase64}`} />
```

After:

```tsx
import Image from "next/image";

<Image src={band.avatarUrl} alt={band.name} width={300} height={300} />;
```

Add your CDN domain and localhost to `next.config.js`:

```js
// next.config.js
module.exports = {
  images: {
    domains: [
      "localhost",
      "goodsongs-production.nyc3.cdn.digitaloceanspaces.com",
    ],
  },
};
```

---

## Phase 7: Direct Uploads (New Uploads Going Forward)

Once migration is done, new uploads should bypass your Rails server entirely and go straight to Spaces. This removes server load and speeds up uploads significantly.

### Step 18: Add direct upload endpoint

```ruby
# config/routes.rb
namespace :api do
  namespace :v1 do
    resources :direct_uploads, only: [:create]
  end
end
```

```ruby
# app/controllers/api/v1/direct_uploads_controller.rb
class Api::V1::DirectUploadsController < ApplicationController
  before_action :authenticate_user!

  def create
    blob = ActiveStorage::Blob.create_before_direct_upload!(**blob_params)
    render json: {
      blob_id:       blob.signed_id,
      key:           blob.key,
      direct_upload: {
        url:     blob.service_url_for_direct_upload,
        headers: blob.service_headers_for_direct_upload
      }
    }
  end

  private

  def blob_params
    params.require(:blob).permit(:filename, :byte_size, :checksum, :content_type)
  end
end
```

### Step 19: Android direct upload flow

```kotlin
// 1. Get presigned URL from your API
val response = api.getDirectUploadUrl(
    filename    = "avatar.jpg",
    byteSize    = file.length(),
    contentType = "image/jpeg",
    checksum    = file.md5Base64()
)

// 2. PUT directly to Spaces — bypasses your Rails server
val request = Request.Builder()
    .url(response.directUpload.url)
    .put(file.asRequestBody("image/jpeg".toMediaType()))
    .apply {
        response.directUpload.headers.forEach { (k, v) -> addHeader(k, v) }
    }
    .build()
OkHttpClient().newCall(request).execute()

// 3. Tell Rails to attach the blob to the band
api.updateBandAvatar(bandId = bandId, blobId = response.blobId)
```

```ruby
# app/controllers/api/v1/bands_controller.rb
def update_avatar
  @band.avatar.attach(params[:blob_id])
  render json: BandSerializer.new(@band)
end
```

---

## Phase 8: Clean Up

After everything is verified working in production and you're confident in the migration, drop the old base64 columns.

### Step 20: Drop the base64 columns

```ruby
# db/migrate/TIMESTAMP_remove_base64_image_columns.rb
class RemoveBase64ImageColumns < ActiveRecord::Migration[7.1]
  def change
    remove_column :bands, :avatar_base64, :text
    remove_column :users, :avatar_base64, :text
    # Add any other base64 columns here
  end
end
```

```bash
bin/rails db:migrate
```

---

## Cost Estimate

| Resource                         | Cost       |
| -------------------------------- | ---------- |
| DO Spaces (250 GB storage)       | $5/mo      |
| DO Spaces CDN (1 TB bandwidth)   | included   |
| Additional bandwidth beyond 1 TB | $0.01/GB   |
| **Total at early scale**         | **~$5/mo** |

---

## Rollback Plan

The base64 columns are untouched until Phase 8. If anything goes wrong before then:

- Revert `production.rb` back to `:local` (or a temporary disk service)
- Re-expose `avatar_base64` in your serializers
- No data has been lost

Only once you run the column drop migration in Phase 8 is the original data gone.

---

## Checklist

- [ ] DO Spaces bucket created
- [ ] CDN enabled on bucket
- [ ] Spaces access keys generated and added to production env
- [ ] `aws-sdk-s3` gem added and bundled
- [ ] `config/storage.yml` updated with `digitalocean` service
- [ ] `development.rb` using `:local`, `production.rb` using `:digitalocean`
- [ ] `default_url_options` set in both environments
- [ ] Active Storage migrations run
- [ ] `has_one_attached` added to all relevant models
- [ ] Rake task written and tested locally
- [ ] Production DB backed up
- [ ] Migration rake task run in production
- [ ] Spot-checked records in production console
- [ ] API serializers updated to return URLs
- [ ] `next.config.js` image domains updated
- [ ] Android loading URLs via Glide/Coil
- [ ] Direct upload endpoint live
- [ ] Old base64 columns dropped
