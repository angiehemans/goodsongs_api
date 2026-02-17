# frozen_string_literal: true

require "test_helper"

class ScrobbleTest < ActiveSupport::TestCase
  def setup
    @user = User.create!(
      email: "test@example.com",
      password: "password123",
      username: "testuser",
      account_type: :fan,
      onboarding_completed: true
    )
  end

  def build_scrobble(attrs = {})
    Scrobble.new({
      user: @user,
      track_name: "Test Song",
      artist_name: "Test Artist",
      album_name: "Test Album",
      duration_ms: 180_000,
      played_at: 1.hour.ago,
      source_app: "goodsongs-test",
      metadata_status: :pending
    }.merge(attrs))
  end

  # Validation tests for Android metadata fields
  test "validates album_artist max length" do
    scrobble = build_scrobble(album_artist: "a" * 501)
    assert_not scrobble.valid?
    assert_includes scrobble.errors[:album_artist], "is too long (maximum is 500 characters)"
  end

  test "allows valid album_artist" do
    scrobble = build_scrobble(album_artist: "Various Artists")
    assert scrobble.valid?
  end

  test "allows nil album_artist" do
    scrobble = build_scrobble(album_artist: nil)
    assert scrobble.valid?
  end

  test "validates genre max length" do
    scrobble = build_scrobble(genre: "a" * 101)
    assert_not scrobble.valid?
    assert_includes scrobble.errors[:genre], "is too long (maximum is 100 characters)"
  end

  test "allows valid genre" do
    scrobble = build_scrobble(genre: "Progressive Rock")
    assert scrobble.valid?
  end

  test "validates year minimum" do
    scrobble = build_scrobble(year: 1799)
    assert_not scrobble.valid?
    assert_includes scrobble.errors[:year], "must be greater than or equal to 1800"
  end

  test "validates year maximum" do
    scrobble = build_scrobble(year: 2101)
    assert_not scrobble.valid?
    assert_includes scrobble.errors[:year], "must be less than or equal to 2100"
  end

  test "allows valid year" do
    scrobble = build_scrobble(year: 2024)
    assert scrobble.valid?
  end

  test "allows nil year" do
    scrobble = build_scrobble(year: nil)
    assert scrobble.valid?
  end

  test "validates artwork_uri max length" do
    scrobble = build_scrobble(artwork_uri: "https://example.com/" + "a" * 2000)
    assert_not scrobble.valid?
    assert_includes scrobble.errors[:artwork_uri], "is too long (maximum is 2000 characters)"
  end

  test "allows valid artwork_uri" do
    scrobble = build_scrobble(artwork_uri: "https://i.scdn.co/image/abc123")
    assert scrobble.valid?
  end

  # effective_artwork_url priority tests
  test "effective_artwork_url returns artwork_uri when present" do
    scrobble = build_scrobble(
      artwork_uri: "https://spotify.com/art.jpg",
      preferred_artwork_url: "https://preferred.com/art.jpg"
    )
    scrobble.save!

    assert_equal "https://spotify.com/art.jpg", scrobble.effective_artwork_url
  end

  test "effective_artwork_url returns preferred_artwork_url when artwork_uri blank and no album_art" do
    scrobble = build_scrobble(
      artwork_uri: nil,
      preferred_artwork_url: "https://preferred.com/art.jpg"
    )
    scrobble.save!

    assert_equal "https://preferred.com/art.jpg", scrobble.effective_artwork_url
  end

  test "effective_artwork_url returns nil when no artwork available" do
    scrobble = build_scrobble
    scrobble.save!

    assert_nil scrobble.effective_artwork_url
  end

  test "effective_artwork_url returns album_art_url when attached and artwork_uri blank" do
    scrobble = build_scrobble(preferred_artwork_url: "https://preferred.com/art.jpg")
    scrobble.save!

    scrobble.album_art.attach(
      io: StringIO.new("fake image data"),
      filename: "test.jpg",
      content_type: "image/jpeg"
    )

    # album_art_url should take priority over preferred_artwork_url
    assert_includes scrobble.effective_artwork_url, "rails/active_storage"
  end

  # album_art attachment tests
  test "has_uploaded_artwork? returns false when no attachment" do
    scrobble = build_scrobble
    scrobble.save!

    assert_not scrobble.has_uploaded_artwork?
  end

  test "has_uploaded_artwork? returns true when attached" do
    scrobble = build_scrobble
    scrobble.save!

    scrobble.album_art.attach(
      io: StringIO.new("fake image data"),
      filename: "test.jpg",
      content_type: "image/jpeg"
    )

    assert scrobble.has_uploaded_artwork?
  end

  test "album_art_url returns nil when not attached" do
    scrobble = build_scrobble
    scrobble.save!

    assert_nil scrobble.album_art_url
  end

  test "album_art_url returns URL when attached" do
    scrobble = build_scrobble
    scrobble.save!

    scrobble.album_art.attach(
      io: StringIO.new("fake image data"),
      filename: "test.jpg",
      content_type: "image/jpeg"
    )

    assert_includes scrobble.album_art_url, "rails/active_storage"
  end

  # album_art validation tests
  test "rejects non-image files" do
    scrobble = build_scrobble

    scrobble.album_art.attach(
      io: StringIO.new("fake pdf data"),
      filename: "test.pdf",
      content_type: "application/pdf"
    )

    assert_not scrobble.valid?
    assert_includes scrobble.errors[:album_art], "must be a JPEG, PNG, or WebP image"
  end

  test "accepts JPEG images" do
    scrobble = build_scrobble

    scrobble.album_art.attach(
      io: StringIO.new("fake jpeg data"),
      filename: "test.jpg",
      content_type: "image/jpeg"
    )

    assert scrobble.valid?
  end

  test "accepts PNG images" do
    scrobble = build_scrobble

    scrobble.album_art.attach(
      io: StringIO.new("fake png data"),
      filename: "test.png",
      content_type: "image/png"
    )

    assert scrobble.valid?
  end

  test "accepts WebP images" do
    scrobble = build_scrobble

    scrobble.album_art.attach(
      io: StringIO.new("fake webp data"),
      filename: "test.webp",
      content_type: "image/webp"
    )

    assert scrobble.valid?
  end
end
