# frozen_string_literal: true

require "test_helper"

class Api::V1::ScrobblesControllerTest < ActionDispatch::IntegrationTest
  def setup
    @user = User.create!(
      email: "test@example.com",
      password: "password123",
      username: "testuser",
      account_type: :fan,
      onboarding_completed: true
    )
    @auth_token = generate_jwt(@user)
  end

  def generate_jwt(user)
    payload = { user_id: user.id, exp: 24.hours.from_now.to_i }
    JWT.encode(payload, Rails.application.secret_key_base)
  end

  def auth_headers
    { "Authorization" => "Bearer #{@auth_token}" }
  end

  def valid_scrobble_params
    {
      scrobbles: [
        {
          track_name: "Test Song",
          artist_name: "Test Artist",
          album_name: "Test Album",
          duration_ms: 180_000,
          played_at: 1.hour.ago.iso8601,
          source_app: "goodsongs-android",
          source_device: "Pixel 8"
        }
      ]
    }
  end

  # Android metadata field tests
  test "accepts album_artist field" do
    params = valid_scrobble_params.deep_dup
    params[:scrobbles][0][:album_artist] = "Various Artists"

    post "/api/v1/scrobbles", params: params, headers: auth_headers, as: :json

    assert_response :created
    scrobble = Scrobble.last
    assert_equal "Various Artists", scrobble.album_artist
  end

  test "accepts genre field" do
    params = valid_scrobble_params.deep_dup
    params[:scrobbles][0][:genre] = "Progressive Rock"

    post "/api/v1/scrobbles", params: params, headers: auth_headers, as: :json

    assert_response :created
    scrobble = Scrobble.last
    assert_equal "Progressive Rock", scrobble.genre
  end

  test "accepts year field" do
    params = valid_scrobble_params.deep_dup
    params[:scrobbles][0][:year] = 2024

    post "/api/v1/scrobbles", params: params, headers: auth_headers, as: :json

    assert_response :created
    scrobble = Scrobble.last
    assert_equal 2024, scrobble.year
  end

  test "accepts release_date field" do
    params = valid_scrobble_params.deep_dup
    params[:scrobbles][0][:release_date] = "2024-03-15"

    post "/api/v1/scrobbles", params: params, headers: auth_headers, as: :json

    assert_response :created
    scrobble = Scrobble.last
    assert_equal Date.new(2024, 3, 15), scrobble.release_date
  end

  test "accepts artwork_uri field" do
    params = valid_scrobble_params.deep_dup
    params[:scrobbles][0][:artwork_uri] = "https://i.scdn.co/image/abc123"

    post "/api/v1/scrobbles", params: params, headers: auth_headers, as: :json

    assert_response :created
    scrobble = Scrobble.last
    assert_equal "https://i.scdn.co/image/abc123", scrobble.artwork_uri
  end

  test "includes android metadata in response" do
    params = valid_scrobble_params.deep_dup
    params[:scrobbles][0].merge!(
      album_artist: "Various Artists",
      genre: "Rock",
      year: 2024,
      artwork_uri: "https://i.scdn.co/image/abc123"
    )

    post "/api/v1/scrobbles", params: params, headers: auth_headers, as: :json

    assert_response :created
    json = JSON.parse(response.body)
    scrobble_data = json["data"]["scrobbles"].first

    assert_equal "Various Artists", scrobble_data["album_artist"]
    assert_equal "Rock", scrobble_data["genre"]
    assert_equal 2024, scrobble_data["year"]
    assert_equal "https://i.scdn.co/image/abc123", scrobble_data["artwork_url"]
  end

  # Base64 album_art tests
  test "accepts data URI format base64 image" do
    jpeg_data = Base64.strict_encode64("\xFF\xD8\xFF\xE0\x00\x10JFIF\x00\x01\x01\x00\x00\x01\x00\x01\x00\x00")
    params = valid_scrobble_params.deep_dup
    params[:scrobbles][0][:album_art] = "data:image/jpeg;base64,#{jpeg_data}"

    post "/api/v1/scrobbles", params: params, headers: auth_headers, as: :json

    assert_response :created
    scrobble = Scrobble.last
    assert scrobble.album_art.attached?
  end

  test "accepts raw base64 image" do
    jpeg_data = Base64.strict_encode64("\xFF\xD8\xFF\xE0\x00\x10JFIF\x00\x01\x01\x00\x00\x01\x00\x01\x00\x00")
    params = valid_scrobble_params.deep_dup
    params[:scrobbles][0][:album_art] = jpeg_data

    post "/api/v1/scrobbles", params: params, headers: auth_headers, as: :json

    assert_response :created
    scrobble = Scrobble.last
    assert scrobble.album_art.attached?
  end

  test "handles invalid base64 gracefully" do
    params = valid_scrobble_params.deep_dup
    params[:scrobbles][0][:album_art] = "not-valid-base64!!!"

    post "/api/v1/scrobbles", params: params, headers: auth_headers, as: :json

    # Should still create the scrobble, just without the attachment
    assert_response :created
    scrobble = Scrobble.last
    assert_not scrobble.album_art.attached?
  end

  # Artwork priority tests
  test "artwork_url returns artwork_uri when present" do
    params = valid_scrobble_params.deep_dup
    params[:scrobbles][0][:artwork_uri] = "https://spotify.com/art.jpg"

    post "/api/v1/scrobbles", params: params, headers: auth_headers, as: :json

    json = JSON.parse(response.body)
    assert_equal "https://spotify.com/art.jpg", json["data"]["scrobbles"].first["artwork_url"]
  end

  # GET scrobbles tests
  test "GET index includes android metadata fields" do
    Scrobble.create!(
      user: @user,
      track_name: "Test Song",
      artist_name: "Test Artist",
      duration_ms: 180_000,
      played_at: 1.hour.ago,
      source_app: "goodsongs-android",
      metadata_status: :pending,
      genre: "Rock",
      year: 2024,
      album_artist: "Various Artists"
    )

    get "/api/v1/scrobbles", headers: auth_headers, as: :json

    assert_response :ok
    json = JSON.parse(response.body)
    scrobble = json["data"]["scrobbles"].first

    assert scrobble.key?("genre")
    assert scrobble.key?("year")
    assert scrobble.key?("album_artist")
    assert scrobble.key?("artwork_url")
  end

  # Validation error tests
  test "rejects invalid year" do
    params = valid_scrobble_params.deep_dup
    params[:scrobbles][0][:year] = 1700

    post "/api/v1/scrobbles", params: params, headers: auth_headers, as: :json

    assert_response :unprocessable_entity
    json = JSON.parse(response.body)
    assert_includes json["error"]["message"], "validation"
  end

  test "rejects genre that is too long" do
    params = valid_scrobble_params.deep_dup
    params[:scrobbles][0][:genre] = "a" * 101

    post "/api/v1/scrobbles", params: params, headers: auth_headers, as: :json

    assert_response :unprocessable_entity
  end
end
