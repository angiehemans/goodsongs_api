# PRD: Social Sharing Phase 1 — Backend

**GoodSongs / Rails API**
**Status:** Draft
**Version:** 1.0

---

## Overview

Phase 1 covers the minimal backend work required to support Intent URL based sharing on Threads and Instagram. No OAuth, no connected accounts, no auto-posting. The backend's only job is to expose a single endpoint that returns a pre-built share payload for any shareable piece of content.

---

## Goals

- Expose a `GET /api/v1/share_payload` endpoint that returns a ready-to-use text caption, canonical URL, image URL, and pre-built Intent URLs for Threads and Instagram
- Centralize all caption-building logic server-side so the frontend never constructs share text itself
- Ensure image URLs returned are stable public CDN URLs suitable for passing to Meta's servers in Phase 2

---

## Out of Scope

Everything OAuth, connected accounts, auto-posting, and token management — those are Phase 2.

---

## API Endpoint

### `GET /api/v1/share_payload`

**Authentication:** Required (standard Bearer token)

**Query params:**

| Param           | Required | Values                                 |
| --------------- | -------- | -------------------------------------- |
| `postable_type` | Yes      | `recommendation`, `band_post`, `event` |
| `postable_id`   | Yes      | String ID of the record                |

**Response:**

```json
{
  "text": "This song hits so hard — Wet Leg, \"Chaise Longue\"\n\nhttps://goodsongs.app/recommendations/abc123",
  "url": "https://goodsongs.app/recommendations/abc123",
  "image_url": "https://cdn.goodsongs.app/album_art/abc.jpg",
  "threads_intent_url": "https://www.threads.net/intent/post?text=This%20song%20hits...",
  "instagram_intent_url": null
}
```

`instagram_intent_url` is `null` in Phase 1 — Instagram does not support a web Intent URL equivalent. The frontend handles Instagram sharing via the Web Share API or clipboard fallback without a pre-built URL from the backend.

`image_url` may be `null` if the content has no associated image (e.g. a text-only band post).

**Errors:**

| Code | Reason                                   |
| ---- | ---------------------------------------- |
| 401  | Unauthenticated                          |
| 404  | Record not found                         |
| 422  | Invalid or unallowlisted `postable_type` |

---

## `SharePayloadBuilder`

A plain Ruby service object. `postable_type` is validated against an allowlist before being constantized.

```ruby
ALLOWED_TYPES = %w[Recommendation BandPost Event].freeze

class SharePayloadBuilder
  MAX_THREADS_CHARS = 500

  def initialize(postable)
    @postable = postable
  end

  def build
    text = build_text
    url  = canonical_url

    {
      text:                 truncate_for_threads(text),
      url:                  url,
      image_url:            resolve_image_url,
      threads_intent_url:   threads_intent_url(text),
      instagram_intent_url: nil
    }
  end

  private

  def build_text
    body = case @postable
    when Recommendation
      "#{@postable.note} — #{@postable.song.artist_name}, \"#{@postable.song.title}\""
    when BandPost
      @postable.body
    when Event
      "#{@postable.name} — #{@postable.venue}, #{@postable.formatted_date}"
    end

    "#{body}\n\n#{canonical_url}"
  end

  def resolve_image_url
    case @postable
    when Recommendation then @postable.song.album_art_cdn_url
    when BandPost        then @postable.cover_image_cdn_url
    when Event           then @postable.flyer_cdn_url
    end
  end

  def canonical_url
    Rails.application.routes.url_helpers.polymorphic_url(
      @postable, host: ENV['APP_HOST']
    )
  end

  def threads_intent_url(text)
    "https://www.threads.net/intent/post?text=#{CGI.escape(text)}"
  end

  def truncate_for_threads(text)
    return text if text.length <= MAX_THREADS_CHARS
    url_length = canonical_url.length + 2
    max_body   = MAX_THREADS_CHARS - url_length
    "#{text[0, max_body - 1]}…\n\n#{canonical_url}"
  end
end
```

---

## Controller

```ruby
class Api::V1::SharePayloadsController < Api::V1::BaseController
  ALLOWED_TYPES = %w[Recommendation BandPost Event].freeze

  def show
    type = params[:postable_type].to_s.camelize
    return render json: { error: "Invalid type" }, status: :unprocessable_entity unless ALLOWED_TYPES.include?(type)

    postable = type.constantize.find(params[:postable_id])
    payload  = SharePayloadBuilder.new(postable).build

    render json: payload
  end
end
```

---

## Tasks

- [ ] `SharePayloadBuilder` service with caption logic for all three content types
- [ ] `Api::V1::SharePayloadsController#show`
- [ ] Route: `GET /api/v1/share_payload`
- [ ] Specs: payload shape for each content type, allowlist enforcement, 404 handling
