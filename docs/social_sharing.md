# PRD: Social Sharing Phase 2 — Backend

**GoodSongs / Rails API**
**Status:** Draft
**Version:** 1.0

---

## Overview

Phase 2 builds on the `SharePayloadBuilder` from Phase 1 and adds OAuth account connections, token storage, and auto-posting for Threads and Instagram. Users can connect their accounts, set per-platform preferences, and have new content automatically posted to their connected platforms.

---

## Prerequisites

Phase 1 backend must be complete. `SharePayloadBuilder` is used directly by both post services in this phase.

---

## Goals

- Allow users to connect Threads and Instagram via OAuth and store credentials securely
- Support auto-posting of new content to connected platforms based on per-user, per-platform preferences
- Detect Instagram account type at connection time and gate auto-posting accordingly (business and creator accounts only)
- Handle token expiry, API failures, and rate limits without surfacing errors to users
- Notify users in-app when a connected account needs to be reconnected

---

## Out of Scope

- Generated share card images
- Facebook Page direct posting
- Twitter/X integration

---

## Data Model

### New Table: `connected_accounts`

```ruby
create_table :connected_accounts do |t|
  t.references :user, null: false, foreign_key: true
  t.string :platform, null: false              # "threads" | "instagram"
  t.string :platform_user_id, null: false
  t.string :platform_username
  t.string :encrypted_access_token, null: false
  t.string :encrypted_access_token_iv, null: false
  t.string :account_type                       # instagram: "BUSINESS" | "CREATOR" | "PERSONAL"
  t.boolean :auto_post_recommendations, default: false   # threads only
  t.boolean :auto_post_band_posts, default: false
  t.boolean :auto_post_events, default: false
  t.boolean :needs_reauth, default: false
  t.datetime :token_expires_at
  t.timestamps
end

add_index :connected_accounts, [:user_id, :platform], unique: true
```

**Notes:**

- Tokens encrypted at rest via `attr_encrypted` or Rails `encrypts`
- One row per platform per user
- `auto_post_recommendations` is only meaningful for Threads; ignored on Instagram rows
- `needs_reauth` flipped to `true` on any 401 from either platform API

---

## OAuth Flows

### Threads

**Scopes:** `threads_basic`, `threads_content_publish`

**Flow:**

1. User initiates from settings — frontend redirects to Threads authorization URL
2. Threads redirects to `/auth/threads/callback?code=...`
3. Rails exchanges code for short-lived token, then exchanges for long-lived token
4. Rails fetches username from `GET https://graph.threads.net/v1.0/me?fields=id,username`
5. Upserts `ConnectedAccount`; returns account details to frontend

```ruby
# Short-lived → long-lived token exchange
POST https://graph.threads.net/access_token
  grant_type:    th_exchange_token
  client_secret: ENV['THREADS_CLIENT_SECRET']
  access_token:  <short_lived_token>
```

Long-lived tokens expire after 60 days. Refresh proactively — see Token Management.

---

### Instagram

**Scopes:** `instagram_basic`, `instagram_content_publish`

**App Review note:** `instagram_content_publish` requires Meta App Review approval before production use. Development proceeds with test users added in Meta's developer dashboard. See App Review section.

**Flow:**

1. User initiates from settings
2. Instagram redirects to `/auth/instagram/callback?code=...`
3. Rails exchanges code for long-lived token
4. Rails fetches account type: `GET https://graph.instagram.com/me?fields=account_type,username`
5. Upserts `ConnectedAccount` with `account_type` populated
6. Returns `account_type` to frontend so the UI can show or hide auto-post toggles accordingly

Account type values: `BUSINESS`, `CREATOR` (auto-post supported), `PERSONAL` (auto-post blocked).

---

## Auto-Post Architecture

### Overview

```
SocialAutoPostJob
  └── ThreadsPostService   (recommendations, band posts, events)
  └── InstagramPostService (band posts, events — BUSINESS/CREATOR only)
```

Both platforms use Meta's two-step container/publish pattern. Services share a base class and the `SocialAutoPostJob` is platform-agnostic.

### `SocialAutoPostJob`

```ruby
class SocialAutoPostJob < ApplicationJob
  queue_as :social_posts
  sidekiq_options retry: 2

  def perform(postable_type, postable_id, platform, user_id)
    user      = User.find(user_id)
    postable  = postable_type.constantize.find(postable_id)
    account   = user.connected_accounts.find_by!(platform: platform)

    return if account.needs_reauth?

    service_class = platform == "threads" ? ThreadsPostService : InstagramPostService
    service_class.new(account, postable).call
  rescue ActiveRecord::RecordNotFound
    nil # postable or account deleted — discard silently
  rescue SocialPostService::ReauthRequired
    account.update!(needs_reauth: true)
    # TODO: trigger in-app notification
  rescue => e
    Rails.logger.error("[SocialAutoPostJob] #{platform} failed for user #{user_id}: #{e.message}")
    raise # allow Sidekiq retry
  end
end
```

### Base Service

```ruby
class SocialPostService
  ReauthRequired = Class.new(StandardError)
  RateLimited    = Class.new(StandardError)

  def initialize(account, postable)
    @account  = account
    @postable = postable
  end

  private

  def handle_response(response)
    case response.code.to_i
    when 200, 201 then JSON.parse(response.body)
    when 401      then raise ReauthRequired
    when 429      then raise RateLimited
    else raise "API error #{response.code}: #{response.body}"
    end
  end
end
```

### `ThreadsPostService`

```ruby
class ThreadsPostService < SocialPostService
  API = "https://graph.threads.net/v1.0"

  def call
    payload      = SharePayloadBuilder.new(@postable).for_threads
    container_id = create_container(payload)
    sleep 3
    publish_container(container_id)
  end

  private

  def create_container(payload)
    response = HTTP.post("#{API}/#{@account.platform_user_id}/threads", form: {
      media_type:   payload[:image_url] ? "IMAGE" : "TEXT",
      text:         payload[:text],
      image_url:    payload[:image_url],
      access_token: @account.decrypted_access_token
    }.compact)
    handle_response(response)["id"]
  end

  def publish_container(container_id)
    response = HTTP.post("#{API}/#{@account.platform_user_id}/threads_publish", form: {
      creation_id:  container_id,
      access_token: @account.decrypted_access_token
    })
    handle_response(response)
  end
end
```

### `InstagramPostService`

Same two-step pattern as Threads with Instagram Graph API endpoints:

```
# Container
POST https://graph.instagram.com/v21.0/{user_id}/media
  image_url, caption, access_token

# Publish
POST https://graph.instagram.com/v21.0/{user_id}/media_publish
  creation_id, access_token
```

Image URLs must be stable public CDN URLs — not short-lived signed URLs.

---

## Auto-Post Triggers

Jobs are enqueued in `after_create` callbacks gated by user preferences and platform eligibility.

```ruby
# Recommendation — Threads only
after_create :enqueue_threads_post

def enqueue_threads_post
  account = user.connected_accounts.find_by(platform: "threads")
  return unless account&.auto_post_recommendations? && !account.needs_reauth?
  SocialAutoPostJob.perform_later("Recommendation", id, "threads", user_id)
end

# BandPost + Event — Threads and Instagram
after_create :enqueue_social_posts

def enqueue_social_posts
  user.connected_accounts.each do |account|
    pref = self.class.name == "BandPost" ? :auto_post_band_posts? : :auto_post_events?
    next unless account.send(pref) && !account.needs_reauth?
    next if account.platform == "instagram" && !%w[BUSINESS CREATOR].include?(account.account_type)
    SocialAutoPostJob.perform_later(self.class.name, id, account.platform, user_id)
  end
end
```

---

## `SharePayloadBuilder` — Phase 2 Additions

Extend the Phase 1 builder with `for_threads` and `for_instagram` methods (Phase 1 only exposes `build` for the API endpoint):

```ruby
def for_threads
  { text: truncate(build_text_body, MAX_THREADS_CHARS), image_url: resolve_image_url }
end

def for_instagram
  { text: truncate(build_text_body, MAX_IG_CHARS), image_url: resolve_image_url }
end
```

---

## Connected Accounts API

| Method | Endpoint                               | Description                    |
| ------ | -------------------------------------- | ------------------------------ |
| GET    | `/api/v1/connected_accounts`           | List user's connected accounts |
| PATCH  | `/api/v1/connected_accounts/:platform` | Update auto-post preferences   |
| DELETE | `/api/v1/connected_accounts/:platform` | Disconnect an account          |
| GET    | `/auth/threads/authorize`              | Initiate Threads OAuth         |
| GET    | `/auth/threads/callback`               | Threads OAuth callback         |
| GET    | `/auth/instagram/authorize`            | Initiate Instagram OAuth       |
| GET    | `/auth/instagram/callback`             | Instagram OAuth callback       |

---

## Token Management

### Refresh Job

Threads and Instagram long-lived tokens expire after 60 days. Refresh proactively at 14 days before expiry.

```ruby
class RefreshSocialTokensJob < ApplicationJob
  def perform
    ConnectedAccount.where("token_expires_at < ?", 14.days.from_now)
                    .where(needs_reauth: false)
                    .find_each do |account|
      SocialTokenRefreshService.new(account).call
    rescue => e
      Rails.logger.warn("Token refresh failed for #{account.id}: #{e.message}")
    end
  end
end
```

Schedule weekly via Sidekiq-Cron or whenever.

### Re-auth on 401

When a post job receives a 401: set `needs_reauth: true`, stop future jobs for that account, and trigger an in-app notification. Clear `needs_reauth` and update the token after successful re-authorization.

---

## Error Handling Summary

| Scenario                              | Behavior                                                 |
| ------------------------------------- | -------------------------------------------------------- |
| 401 from platform                     | Set `needs_reauth: true`, notify user, stop future posts |
| 429 rate limit                        | Raise, allow Sidekiq retry with backoff                  |
| Network timeout                       | Raise, allow Sidekiq retry (max 2)                       |
| Postable deleted before job runs      | Catch `RecordNotFound`, discard                          |
| Instagram personal account            | Blocked at eligibility check — job never enqueued        |
| Publish fails after container created | Log, do not retry publish without new container          |

---

## Security

- Tokens encrypted at rest
- OAuth `state` param validated on callback (CSRF protection)
- `postable_type` allowlisted before `constantize`
- Token values never appear in logs

---

## Meta App Review

`instagram_content_publish` requires Meta App Review before production. Required before launch:

1. Complete publishing flow in staging using Meta test users
2. Record screen capture of OAuth connection and auto-post
3. Submit via Meta for Developers: use case — "Allow musicians to auto-post GoodSongs events and band updates to their Instagram business accounts"
4. Include GoodSongs privacy policy URL

Allocate 1–2 weeks. All other work can proceed in parallel.

---

## Tasks

**Data model**

- [ ] `connected_accounts` migration
- [ ] `ConnectedAccount` model with validations and encrypted token fields

**Threads OAuth**

- [ ] `Auth::ThreadsController#authorize` and `#callback`
- [ ] Long-lived token exchange
- [ ] Token refresh (Threads)

**Instagram OAuth**

- [ ] `Auth::InstagramController#authorize` and `#callback`
- [ ] Account type fetch and storage
- [ ] Token refresh (Instagram)

**Services and jobs**

- [ ] Extend `SharePayloadBuilder` with `for_threads` and `for_instagram`
- [ ] `SocialPostService` base class
- [ ] `ThreadsPostService`
- [ ] `InstagramPostService`
- [ ] `SocialAutoPostJob`

**Triggers**

- [ ] `Recommendation` after_create hook
- [ ] `BandPost` after_create hook
- [ ] `Event` after_create hook

**Connected Accounts API**

- [ ] `GET /api/v1/connected_accounts`
- [ ] `PATCH /api/v1/connected_accounts/:platform`
- [ ] `DELETE /api/v1/connected_accounts/:platform`

**Notifications**

- [ ] In-app notification on `needs_reauth`
- [ ] Clear flag and update token on re-auth success

**Meta**

- [ ] Meta App Review submission for `instagram_content_publish`

Both platforms use the same Meta developer account. You'll need to:

1. Create a Meta Developer account (if you don't have one)
2. Create an app (one app can have both products)
3. Submit for App Review to get permissions (threads_basic, threads_content_publish, instagram_basic,  
   instagram_content_publish) approved for public use
4. Set these 6 env vars in production:  


THREADS_CLIENT_ID=...  
 THREADS_CLIENT_SECRET=...  
 THREADS_REDIRECT_URI=https://api.goodsongs.app/auth/threads/callback
INSTAGRAM_CLIENT_ID=...  
 INSTAGRAM_CLIENT_SECRET=...
INSTAGRAM_REDIRECT_URI=https://api.goodsongs.app/auth/instagram/callback
