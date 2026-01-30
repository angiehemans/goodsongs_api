# frozen_string_literal: true

class MigrateArtistsToBands < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def up
    # Build a mapping of artist_id (UUID) → band_id (bigint)
    artist_to_band = {}

    # Use raw SQL to avoid dependency on the Artist model (which will be deleted)
    select_all("SELECT id, name, musicbrainz_artist_id, image_url, bio FROM artists").each do |artist|
      band_id = nil

      # 1. Match by musicbrainz_id first
      if artist["musicbrainz_artist_id"].present?
        band = select_one("SELECT id FROM bands WHERE musicbrainz_id = #{quote(artist['musicbrainz_artist_id'])}")
        if band
          band_id = band["id"]
          # Backfill blank fields on the matched band
          updates = []
          existing_band = select_one("SELECT artist_image_url, about, musicbrainz_id FROM bands WHERE id = #{band_id}")
          if existing_band["artist_image_url"].blank? && artist["image_url"].present?
            updates << "artist_image_url = #{quote(artist['image_url'])}"
          end
          if existing_band["about"].blank? && artist["bio"].present?
            updates << "about = #{quote(artist['bio'])}"
          end
          execute("UPDATE bands SET #{updates.join(', ')}, updated_at = NOW() WHERE id = #{band_id}") if updates.any?
        end
      end

      # 2. Match by case-insensitive name
      if band_id.nil? && artist["name"].present?
        band = select_one("SELECT id FROM bands WHERE LOWER(name) = LOWER(#{quote(artist['name'])})")
        if band
          band_id = band["id"]
          # Backfill musicbrainz_id and other blank fields
          existing_band = select_one("SELECT artist_image_url, about, musicbrainz_id FROM bands WHERE id = #{band_id}")
          updates = []
          if existing_band["musicbrainz_id"].blank? && artist["musicbrainz_artist_id"].present?
            updates << "musicbrainz_id = #{quote(artist['musicbrainz_artist_id'])}"
          end
          if existing_band["artist_image_url"].blank? && artist["image_url"].present?
            updates << "artist_image_url = #{quote(artist['image_url'])}"
          end
          if existing_band["about"].blank? && artist["bio"].present?
            updates << "about = #{quote(artist['bio'])}"
          end
          execute("UPDATE bands SET #{updates.join(', ')}, updated_at = NOW() WHERE id = #{band_id}") if updates.any?
        end
      end

      # 3. Create new band if no match found
      if band_id.nil?
        slug = artist["name"].to_s.downcase.gsub(/[^a-z0-9\-_]/, "-").gsub(/-+/, "-").gsub(/^-+|-+$/, "")
        slug = "band" if slug.blank?

        # Ensure slug uniqueness
        base_slug = slug
        counter = 1
        while select_one("SELECT 1 FROM bands WHERE slug = #{quote(slug)}")
          slug = "#{base_slug}-#{counter}"
          counter += 1
        end

        execute(<<~SQL)
          INSERT INTO bands (name, musicbrainz_id, artist_image_url, about, slug, user_id, created_at, updated_at)
          VALUES (
            #{quote(artist['name'])},
            #{quote(artist['musicbrainz_artist_id'])},
            #{quote(artist['image_url'])},
            #{quote(artist['bio'])},
            #{quote(slug)},
            NULL,
            NOW(),
            NOW()
          )
        SQL

        band_id = select_value("SELECT id FROM bands WHERE slug = #{quote(slug)}")
      end

      artist_to_band[artist["id"]] = band_id
    end

    # Set band_id on albums and tracks from the mapping
    artist_to_band.each do |artist_id, band_id|
      execute("UPDATE albums SET band_id = #{band_id} WHERE artist_id = #{quote(artist_id)}")
      execute("UPDATE tracks SET band_id = #{band_id} WHERE artist_id = #{quote(artist_id)}")
    end

    # Remove old FK constraints
    remove_foreign_key :albums, :artists if foreign_key_exists?(:albums, :artists)
    remove_foreign_key :tracks, :artists if foreign_key_exists?(:tracks, :artists)

    # Remove old artist_id columns
    remove_column :albums, :artist_id
    remove_column :tracks, :artist_id

    # Add new FK constraints for band_id
    add_foreign_key :albums, :bands
    add_foreign_key :tracks, :bands

    # Drop artists table
    drop_table :artists
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end

  private

  def quote(value)
    ActiveRecord::Base.connection.quote(value)
  end
end
