# GoodSongs API - Project Review

Comprehensive review covering security, performance, efficiency, and code quality.

---

## Table of Contents

- [Security](#security)
  - [Critical](#critical-security)
  - [High](#high-security)
  - [Medium](#medium-security)
  - [Low](#low-security)
- [Performance & Efficiency](#performance--efficiency)
  - [N+1 Queries](#n1-queries)
  - [Missing Database Indexes](#missing-database-indexes)
  - [Missing Pagination](#missing-pagination)
  - [Counter Caches](#counter-caches)
  - [Caching & Infrastructure](#caching--infrastructure)
  - [External API Calls](#external-api-calls)
- [Code Quality & Architecture](#code-quality--architecture)
  - [Duplicated Code](#duplicated-code)
  - [Model Issues](#model-issues)
  - [Config & Infrastructure](#config--infrastructure)
  - [Error Handling](#error-handling)
  - [Test Coverage](#test-coverage)
- [Frontend Changes Required](#frontend-changes-required)
- [Priority Summary](#priority-summary)

---

## Security

### Critical Security

#### ~~1. Firebase Service Account Private Key on Disk~~ DONE

**File:** `config/firebase-service-account.json`

A full Firebase service account JSON with a live RSA private key is on disk. It is in `.gitignore` and not committed, but one accidental `git add .` away from exposure.

**Action:** Rotate/revoke the key in Google Cloud Console immediately. Store the credential via `ENV['FIREBASE_SERVICE_ACCOUNT_JSON']` or Rails encrypted credentials. Remove the file from disk.

**Resolution:** File deleted from disk. File fallback removed from `PushNotificationService` - it now only reads from `FIREBASE_SERVICE_ACCOUNT_JSON_BASE64` or `FIREBASE_SERVICE_ACCOUNT_JSON` env vars. Deploy config already uses `FIREBASE_SERVICE_ACCOUNT_JSON_BASE64`. **Key still needs to be rotated in Google Cloud Console and the new key set as the env var.**

---

### High Security

#### ~~2. Email Leaked in Public Profile Endpoint~~ DONE

**File:** `app/serializers/user_serializer.rb:59`

```ruby
def self.public_profile(user)
  result = {
    email: user.email,   # exposed on unauthenticated endpoints
    ...
  }
```

`public_profile` is called from unauthenticated endpoints (`GET /users/:username`, `GET /api/v1/profiles/:username`). Any visitor can see any user's email address.

**Fix:** Remove `email:` from `public_profile`. Email should only appear in `profile_data` (the authenticated self-view).

**Resolution:** Removed `email: user.email` from `UserSerializer.public_profile`. Email remains available in `profile_data` (authenticated self-view) and `admin_user_data_full` (admin detail view).

#### ~~3. `permit!` and `to_unsafe_h` in ProfileThemesController~~ DONE

**File:** `app/controllers/api/v1/profile_themes_controller.rb:132`

```ruby
ActionController::Parameters.new(result).permit!
```

`permit!` bypasses Rails strong parameters. Combined with `to_unsafe_h` on nested `content` and `settings`, unexpected keys could flow through to the model.

**Fix:** Replace with explicit `permit(:background_color, :brand_color, ...)` and whitelist section fields instead of using `to_unsafe_h`.

**Resolution:** Removed `permit!` and `to_unsafe_h`. Global theme fields remain explicitly whitelisted. Section `content`/`settings` are now processed through a `sanitize_json` method that recursively converts params to plain Ruby hashes, only allowing JSON-safe types (String, Integer, Float, Boolean, nil) and enforcing a max nesting depth of 5. This keeps the schema flexible for the evolving site builder while preventing non-JSON-safe objects from flowing through. The existing `ProfileThemeValidator` continues to validate field values against the section schema.

#### ~~4. No Rate Limiting on Login~~ DONE

**File:** `app/controllers/authentication_controller.rb`

`POST /login` and `POST /auth/refresh` have no rate limiting. No `rack-attack` gem is installed despite `RateLimitedError` being defined in `ApiErrorHandler`. This allows unlimited brute-force login attempts.

**Fix:** Add `rack-attack` with rules like 5 attempts per email per 20 minutes and 20 attempts per IP per minute on `/login` and `/auth/refresh`.

**Resolution:** Added application-level rate limiting using `Rails.cache` (same pattern as scrobbles). Login: 5 attempts per email and 20 per IP per 15-minute window. Refresh: 30 per IP per 15-minute window. Email keys are SHA256-hashed to avoid leaking emails in cache keys.

#### ~~5. Scrobble History Publicly Accessible~~ DONE

**File:** `app/controllers/api/v1/scrobbles_controller.rb:107-121`

```ruby
def user_scrobbles
  user = User.find(params[:user_id])
  # TODO: Check privacy settings when implemented
  scrobbles = user.scrobbles.recent
```

Any authenticated user can view any other user's full listening history with no privacy control.

**Fix:** Require `user_id == current_user.id` or implement a privacy setting check.

**Resolution:** Added authorization check — returns 403 unless `user == current_user`. Can be relaxed later when privacy settings are implemented.

#### ~~6. Refresh Token Rotation Disabled~~ DONE

**File:** `app/controllers/authentication_controller.rb:48-51`

Refresh token rotation code is written but commented out. Without rotation, a stolen refresh token can mint new access tokens for 90 days undetected.

**Fix:** Uncomment the refresh token rotation code.

**Resolution:** Enabled refresh token rotation. On `POST /auth/refresh`, the old token is revoked and a new `refresh_token` is returned in the response. **Frontend must store the new refresh token from each refresh response.**

#### ~~7. Password Reset Doesn't Revoke Existing Sessions~~ DONE

**File:** `app/controllers/password_reset_controller.rb:62-67`

After password reset, existing refresh tokens are not revoked. An attacker with a stolen refresh token retains access even after the user resets their password.

**Fix:** Call `RefreshToken.revoke_all_for_user(user)` on password reset and issue a new refresh token alongside the access token.

**Resolution:** `PasswordResetService#reset_password!` now calls `RefreshToken.revoke_all_for_user` after saving. `PasswordResetController#update` now returns both `auth_token` and `refresh_token` in the response so the user has a fresh session immediately.

---

### Medium Security

#### ~~8. JWT Algorithm Not Explicitly Specified~~ DONE

**File:** `app/services/json_web_token.rb`

```ruby
JWT.encode(payload, SECRET_KEY)       # no algorithm
JWT.decode(token, SECRET_KEY)[0]      # no algorithm - accepts any!
```

Not specifying the algorithm in `decode` is a known JWT vulnerability (`alg: none` attack).

**Fix:**

```ruby
JWT.encode(payload, SECRET_KEY, 'HS256')
JWT.decode(token, SECRET_KEY, true, algorithms: ['HS256'])
```

**Resolution:** Added explicit `'HS256'` algorithm to both `encode` and `decode`. Decode now rejects tokens with any other algorithm.

#### ~~9. `UserSerializer.profile_data` Uses Denylist Pattern~~ DONE

**File:** `app/serializers/user_serializer.rb:6-18`

```ruby
base_data = user.as_json(except: [:password_digest, :spotify_access_token, ...])
```

Uses `as_json(except: [...])` - any new sensitive column added to `users` is automatically exposed until someone remembers to exclude it.

**Fix:** Convert to an explicit allowlist (`only: [...]`).

**Resolution:** Replaced `as_json(except: [...]).merge(...)` with a single explicit hash listing every field. New columns must be deliberately added to the serializer to be exposed.

#### ~~10. Admin Privilege Escalation~~ DONE

**File:** `app/controllers/admin_controller.rb:391-406`

`admin_user_params` allows setting `admin: true`. Any admin can promote any user to admin with no additional checks or audit logging.

**Fix:** Add audit logging for admin privilege changes. Consider requiring a super-admin role.

**Resolution:** Added `[AdminAudit]` logging for changes to `admin`, `role`, `plan_id`, and `disabled` fields. Logs include the acting admin, target user, old/new values, and IP address.

#### ~~11. No Content-Type Validation on Scrobble Album Art~~ DONE

**File:** `app/controllers/api/v1/scrobbles_controller.rb`

The content type from data URIs is passed directly to Active Storage without validation. An attacker could upload `application/x-php` content. `BlogImagesController` correctly validates against `ALLOWED_CONTENT_TYPES`, but scrobble uploads do not.

**Fix:** Add allowlist check: `return unless %w[image/jpeg image/png image/webp image/gif].include?(content_type)`

**Resolution:** Added `ALLOWED_IMAGE_TYPES` constant and a check that rejects any content type not in `[image/jpeg, image/png, image/webp, image/gif]` before attaching.

#### ~~12. `constantize` on DB Values Without Re-validation~~ DONE

**File:** `app/controllers/api/v1/analytics_controller.rb:92`

```ruby
viewable = viewable_type.constantize.find_by(id: viewable_id)
```

While mitigated at the write layer (tracking controller uses `VIEWABLE_TYPES` allowlist), the analytics controller doesn't re-validate.

**Fix:** Add `raise unless %w[Post Band Event].include?(viewable_type)` before `constantize`.

**Resolution:** Added `next unless PageView::VALID_VIEWABLE_TYPES.include?(viewable_type)` before `constantize`, reusing the existing model-level allowlist.

---

### Low Security

#### ~~13. Bare `rescue` Swallows All Exceptions~~ DONE

**File:** `app/controllers/concerns/authenticable.rb:17-21`

```ruby
def authenticate_request_optional
  @current_user = AuthorizeApiRequest.new(request.headers).call[:user]
rescue
  @current_user = nil
end
```

Catches `NoMemoryError`, `SignalException`, database connection errors, etc. A database outage would silently make all users appear unauthenticated.

**Fix:** Rescue only `ExceptionHandler::AuthenticationError, ExceptionHandler::MissingToken, ExceptionHandler::InvalidToken, ExceptionHandler::ExpiredToken`.

**Resolution:** Both `authenticate_request_optional` and `authenticated_user` now rescue only the four specific auth exception types.

#### ~~14. CORS Includes Localhost in All Environments~~ DONE

**File:** `config/initializers/cors.rb`

Localhost origins are included alongside production origins. Any service on a developer's machine can make credentialed requests.

**Fix:** Wrap localhost origins in `Rails.env.development?`.

**Resolution:** Localhost origins are now only added in `development` and `test` environments. Production CORS only allows `goodsongs.app` origins.

#### ~~15. Sensitive Tokens Not in Parameter Filter~~ DONE

**File:** `config/initializers/filter_parameter_logging.rb`

`spotify_access_token`, `spotify_refresh_token`, and `lastfm_username` are not filtered from logs.

**Fix:** Add `:spotify_access_token, :spotify_refresh_token, :access_token, :refresh_token` to `filter_parameters`.

**Resolution:** Added `:access_token, :refresh_token, :spotify_access_token, :spotify_refresh_token` to `filter_parameters`. Note: `:token` was already in the list which partially matches, but the explicit entries ensure exact matches are filtered too.

#### ~~16. Login Timing Attack Enables Email Enumeration~~ DONE

**File:** `app/services/authenticate_user.rb`

Non-existent users skip `authenticate(password)`, making the response measurably faster than for wrong-password attempts. This allows email enumeration via timing.

**Fix:** Always call `BCrypt::Password.new(DUMMY_HASH).is_password?(password)` when user is not found.

**Resolution:** Added a `DUMMY_PASSWORD_HASH` constant and a dummy bcrypt comparison when the user is not found. Response time is now consistent regardless of whether the email exists.

---

## Performance & Efficiency

### N+1 Queries

#### ~~17. `BandSerializer.summary` Fires COUNT Query Per Band~~ DONE

**File:** `app/serializers/band_serializer.rb:12`

```ruby
reviews_count: band.reviews.count,  # SQL COUNT per band
```

Called in loops across `BandsController#index`, `DiscoverController`, `UserSerializer`. Even with `includes(:reviews)`, `.count` bypasses the eager-loaded cache and fires a new query.

**Fix:** Use `band.reviews.size` (uses eager-loaded cache) or add a `reviews_count` counter cache column.

#### ~~18. `ReviewSerializer.full` - ~5 Extra Queries Per Review~~ DONE

**File:** `app/serializers/review_serializer.rb:6-7`

Each call fires queries for: `mentions`, `band.reviews.count`, `liked_by?(current_user)`, `comments_count`, `likes_count`. For 20 reviews = ~100 extra queries.

**Fix:** Add `includes(:mentions, :review_likes, :review_comments)` in `QueryService`, add counter caches for likes/comments.

#### ~~19. `DiscoverController#discover_user_data` - 4 Queries Per User~~ DONE

**File:** `app/controllers/discover_controller.rb:245-249`

```ruby
reviews_count: user.reviews.count,     # ignores counter cache
followers_count: user.followers.count, # ignores counter cache
following_count: user.following.count  # ignores counter cache
bands_count: user.bands.count          # no counter cache
```

The User model has `reviews_count`, `followers_count`, `following_count` counter cache columns. Read from them directly instead of calling `.count`.

**Fix:** Use `user.reviews_count`, `user.followers_count`, `user.following_count` (the cached column values).

#### ~~20. `NotificationsController#index` - N+1 on Polymorphic Associations~~ DONE

**File:** `app/controllers/notifications_controller.rb:14`

`notification_data` accesses `notification.actor` and `notification.notifiable` without eager loading.

**Fix:** `current_user.notifications.recent.includes(:actor, :notifiable)`

#### ~~21. `BlogDashboardController#top_performing_posts_data` - 2 Queries Per Post~~ DONE

**File:** `app/controllers/api/v1/blog_dashboard_controller.rb:137-150`

```ruby
likes = post.post_likes.count      # per post
comments = post.post_comments.count # per post
```

**Fix:** Use `includes(:post_likes, :post_comments)` and `.size`, or use SQL aggregation.

---

### Missing Database Indexes

#### ~~22. Trigram Indexes Missing for Search~~ DONE

**Files affected:** `reviews.band_name`, `reviews.song_name`, `users.username`

`DiscoverController` uses trigram similarity (`%` operator) on these columns but there are no GIN trigram indexes. Every search does a full table scan.

**Migration needed:**

```ruby
add_index :reviews, :band_name, name: "index_reviews_on_band_name_trgm", using: :gin, opclass: :gin_trgm_ops
add_index :reviews, :song_name, name: "index_reviews_on_song_name_trgm", using: :gin, opclass: :gin_trgm_ops
add_index :users, :username, name: "index_users_on_username_trgm", using: :gin, opclass: :gin_trgm_ops
```

#### ~~23. `bands.discogs_artist_id` Has No Index~~ DONE

`ScrobbleEnrichmentService` does `Band.find_by(discogs_artist_id: artist_id)` repeatedly - full table scan each time.

**Migration needed:**

```ruby
add_index :bands, :discogs_artist_id, unique: true, where: "discogs_artist_id IS NOT NULL"
```

#### ~~24. `page_views` Missing Composite Index for Dedup~~ DONE

`TrackingController#duplicate_view?` queries `(viewable_type, viewable_id, session_id, created_at)` on every page view - no index covers this.

**Migration needed:**

```ruby
add_index :page_views, [:viewable_type, :viewable_id, :session_id, :created_at],
          name: "index_page_views_on_dedup"
```

#### ~~25. `users.disabled` and `users.onboarding_completed` Unindexed~~ DONE

Frequently filtered in `DiscoverController` and `BandsController`. No index exists.

---

### ~~Missing Pagination~~ DONE

**Resolution:** Created `Paginatable` concern with `page_param`, `per_page_param`, `paginate`, and `pagination_meta` helpers. Applied to `BandsController`, `EventsController`, `ReviewsController`, and `FollowsController`. All list endpoints now accept `?page=` and `?per_page=` params (default 20, max 100) and return `pagination` metadata.

The following endpoints now return paginated result sets:

| Endpoint                  | File                        | Impact                   |
| ------------------------- | --------------------------- | ------------------------ |
| `GET /bands`              | `bands_controller.rb:9`     | All bands, each with N+1 |
| `GET /events`             | `events_controller.rb:11`   | All upcoming events      |
| `GET /bands/:slug/events` | `events_controller.rb:17`   | All band events          |
| `GET /users/:id/events`   | `events_controller.rb:23`   | All user events          |
| `GET /users/:id/reviews`  | `reviews_controller.rb:100` | All user reviews         |
| `GET /following`          | `follows_controller.rb:44`  | All followed users       |
| `GET /followers`          | `follows_controller.rb:55`  | All followers            |
| `GET /bands/user`         | `bands_controller.rb`       | All user's bands         |

**Fix:** Add `page` and `per_page` params with sensible defaults (e.g., 20) and return pagination metadata.

---

### ~~Counter Caches~~ DONE

**Resolution:** Created migration adding `review_likes_count`, `review_comments_count` to reviews, `reviews_count` to bands, `post_likes_count`, `post_comments_count` to posts. Added `counter_cache: true` to `ReviewLike`, `ReviewComment`, `PostLike`, `PostComment`. Models use fallback pattern `self[:column] || association.size`.

These models previously computed counts via live queries:

| Model    | Missing Counter Cache           | Called From                       |
| -------- | ------------------------------- | --------------------------------- |
| `Review` | `likes_count`, `comments_count` | `ReviewSerializer.full`           |
| `Post`   | `likes_count`, `comments_count` | `PostSerializer`, `BlogDashboard` |
| `Band`   | `reviews_count`                 | `BandSerializer.summary/full`     |

**Fix:** Add counter cache columns and use `counter_cache: true` on the `belongs_to` side of each association.

---

### Caching & Infrastructure

#### ~~26. Production Uses `:async` Job Adapter~~ DONE

**File:** `config/environments/production.rb:51`

```ruby
config.active_job.queue_adapter = :async
```

Jobs run in-process and are **lost on server restart**. This affects emails, push notifications, scrobble enrichment, scheduled post publishing, and token cleanup. `solid_queue` is already in the Gemfile.

**Fix:** Switch to `config.active_job.queue_adapter = :solid_queue`.

**Resolution:** Switched to `:solid_queue`. Requires `solid_queue` database tables to exist — run `bin/rails solid_queue:install:migrations && bin/rails db:migrate` on deploy.

#### 27. ActiveStorage Uses `:local` in Production

**File:** `config/environments/production.rb:22`

Files stored on the server filesystem are lost on ephemeral cloud deployments (Heroku, Fly.io, Render). Serving files through Rails instead of a CDN is significantly slower.

**Fix:** Switch to S3/GCS with a CDN.

#### 28. No HTTP Caching on Public Endpoints

No `Cache-Control`, `ETag`, or `stale?` headers on read-heavy public endpoints like `GET /bands/:slug`, `GET /blogs/:username`, `GET /discover/*`.

**Fix:** Add `expires_in` or `stale?` checks on public read endpoints.

#### 29. No Image Variant Resizing

Calls like `url_for(user.profile_image)` serve original full-size uploads. A 5MB photo is sent to every consumer.

**Fix:** Use Active Storage variants: `.variant(resize_to_limit: [400, 400])` for profile images.

#### ~~30. `mini_magick` Variant Processor~~ DONE

**File:** `config/environments/production.rb:55`

`mini_magick` uses more memory than `libvips`.

**Fix:** Switch to `config.active_storage.variant_processor = :vips`.

**Resolution:** Switched to `:vips`. Requires `libvips` to be installed on the server (e.g. `apt-get install libvips42`).

---

### External API Calls

#### ~~31. `LastfmController#connect` and `#status` - No Timeout~~ DONE

**File:** `app/controllers/lastfm_controller.rb`

Synchronous Last.fm API calls with no configured timeout. If Last.fm is slow, the Rails thread blocks for up to 60 seconds (HTTParty default).

**Fix:** Add explicit timeouts: `HTTParty.get(url, timeout: 5)`.

**Resolution:** Added `default_timeout 10` to `LastfmService`, `LastfmArtistService`, and `MusicbrainzService`. All external HTTP calls now timeout after 10 seconds.

#### ~~32. `MusicbrainzService.get_artist` Called Outside Cache~~ DONE

**File:** `app/services/scrobble_enrichment_service.rb:109,133`

`find_or_create_band` and `backfill_band_from_musicbrainz` call `MusicbrainzService.get_artist` directly without going through `ScrobbleCacheService`. Identical artist fetches hit the external API multiple times.

**Fix:** Route through `ScrobbleCacheService` for all MusicBrainz calls.

**Resolution:** Added `get_musicbrainz_artist(mbid)` to `ScrobbleCacheService` with 24-hour TTL. Updated both call sites in `ScrobbleEnrichmentService` to use the cached version.

---

## Code Quality & Architecture

### Duplicated Code

#### ~~33. `active_storage_url_options` Duplicated 11 Times~~ DONE

Identical method appears in:

- `Band`, `Scrobble`, `Post`, `Album`, `BlogImage`, `ProfileAsset` (models)
- `ImageCachingService`, `ProfileSectionResolver` (services)
- `FanDashboardController`, `BlogDashboardController`, `BloggerDashboardController` (controllers)

**Fix:** Extract into a shared `ImageUrlHelper` concern included in `ApplicationRecord` and `ApplicationController`.

**Resolution:** Added `self.active_storage_url_options` class method and `active_storage_url_options` instance method to `ImageUrlHelper`. Models include the module directly. Services/controllers call `ImageUrlHelper.active_storage_url_options`. All 11 local copies removed. Also consolidated `attachment_url` to use `rails_blob_url` instead of `url_for` with `default_url_options`.

#### ~~34. `QueryService.following_feed` and `following_feed_count` Duplicate Logic~~ DONE

Both methods independently run the same `pluck(:id)` queries and condition-building logic.

**Fix:** Extract a private `following_feed_scope(user)` method.

**Resolution:** Extracted `following_feed_scope(user)` as a private class method. Both `following_feed` and `following_feed_count` now delegate to it.

#### ~~35. `ProfileSectionResolver` and `ProfileThemeSerializer` Duplicate Link Building~~ DONE

`configured_streaming_links` and `configured_social_links` in the resolver are identical to `build_streaming_links` and `build_social_links` in the serializer.

**Fix:** Extract into a shared helper module.

**Resolution:** Created `ProfileLinkHelper` module with `streaming_links(band)` and `social_links(user, band)` class methods. Both `ProfileThemeSerializer` and `ProfileSectionResolver` now delegate to the shared helper.

---

### Model Issues

#### ~~36. `Follow` Model Missing Self-Follow Prevention~~ DONE

```ruby
# No validation preventing user.follow(user)
validates :follower_id, uniqueness: { scope: :followed_id }
```

**Fix:** Add `validate :cannot_follow_self` with `errors.add(:followed_id, "can't follow yourself") if follower_id == followed_id`.

**Resolution:** Added `cannot_follow_self` validation to `Follow` model.

#### ~~37. `User#send_confirmation_email` Fires Extra UPDATE~~ DONE

```ruby
after_create :send_confirmation_email

def send_confirmation_email
  generate_email_confirmation_token!  # calls save! - second write after INSERT
end
```

**Fix:** Use `before_create` to set the token, avoiding the extra `UPDATE`.

**Resolution:** Added `before_create :set_email_confirmation_token` to generate the token during the initial INSERT. Changed `after_create` to `after_create_commit` for the mailer job. No extra UPDATE query on user creation.

#### ~~38. Missing Mailer Views~~ NOT AN ISSUE

Only `confirmation_email.html.erb` exists. `password_reset_email` and `welcome_email` templates are missing and will raise `ActionView::MissingTemplate` when called.

All six mailer views exist: `confirmation_email.html.erb`, `confirmation_email.text.erb`, `password_reset_email.html.erb`, `password_reset_email.text.erb`, `welcome_email.html.erb`, `welcome_email.text.erb`. No action needed.

---

### Config & Infrastructure

#### ~~39. `solid_queue` in Gemfile But Unused~~ DONE

The gem adds boot weight for no benefit since production uses `:async`.

**Fix:** Either switch to `solid_queue` (recommended) or remove from Gemfile.

**Resolution:** Production now uses `:solid_queue` (see #26).

#### ~~40. `rack-cors` Declared Twice in Gemfile~~ DONE

Line 16 (active, no version pin) and line 53 (commented out from generator).

**Fix:** Remove the duplicate and pin the version.

**Resolution:** Removed the commented-out duplicate `rack-cors` line from the Gemfile.

#### ~~41. `jwt` Gem Has No Version Pin~~ DONE

JWT is security-sensitive. A major version bump could change algorithm defaults.

**Fix:** Pin to a specific major version: `gem 'jwt', '~> 2.7'`.

**Resolution:** Pinned to `gem 'jwt', '~> 2.7'` in the Gemfile.

---

### Error Handling

#### 42. Two Competing Error Handler Concerns

`ExceptionHandler` returns `{ error: "message" }` while `ApiErrorHandler` returns `{ error: { code: ..., message: ... } }`. Clients get inconsistent error formats depending on whether the endpoint is under `/api/v1/` or not.

**Fix:** Standardize on one error format across all controllers.

#### ~~43. `Ownership` Concern Calls Undefined `render_unauthorized`~~ DONE

`Ownership` calls `render_unauthorized` which is defined in `ResourceController`. If a controller includes `Ownership` without `ResourceController`, it raises `NoMethodError` at runtime.

**Fix:** Make `Ownership` define its own `render_unauthorized` or declare the dependency.

**Resolution:** Added `render_unauthorized` directly to the `Ownership` concern. Controllers that include both `ResourceController` and `Ownership` will use `ResourceController`'s version (Ruby method resolution order), while controllers with only `Ownership` will use the built-in fallback.

---

### Test Coverage

Only 2 test files exist for the entire application:

```
test/models/scrobble_test.rb
test/controllers/api/v1/scrobbles_controller_test.rb
```

`rspec-rails` and `factory_bot_rails` are in the Gemfile but `spec/` directory doesn't exist. Zero coverage for authentication, reviews, profiles, follows, notifications, posts, mailers, jobs, and serializers.

**Fix:** Prioritize tests for authentication, authorization, and data serialization (where security issues are most likely to hide).

---

## Frontend Changes Required

The following completed items change API behavior and require frontend updates.

### Breaking Changes (will break existing frontend if not updated)

#### Pagination Response Shape Changed
**Affects:** `GET /bands`, `GET /events`, `GET /bands/:slug/events`, `GET /users/:id/events`, `GET /users/:id/reviews`, `GET /following`, `GET /followers`, `GET /users/:id/following`, `GET /users/:id/followers`

These endpoints previously returned a flat JSON array. They now return a wrapped object with pagination metadata:

```json
// Before
[{ "id": 1, "name": "..." }, ...]

// After
{
  "bands": [{ "id": 1, "name": "..." }, ...],
  "pagination": {
    "current_page": 1,
    "per_page": 20,
    "total_count": 87,
    "total_pages": 5,
    "has_next_page": true,
    "has_previous_page": false
  }
}
```

The data key varies by endpoint: `bands`, `events`, `reviews`, or `users`. Endpoints accept optional `?page=1&per_page=20` query params (default 20, max 100).

#### Refresh Token Rotation (#6)
**Affects:** `POST /auth/refresh`

The refresh response now returns a **new** `refresh_token` alongside the `auth_token`. The old refresh token is immediately revoked.

```json
{
  "auth_token": "new_access_token",
  "refresh_token": "new_refresh_token",
  "expires_in": 900
}
```

**Frontend must:** Store the new `refresh_token` from every refresh response. Using the old token after a refresh will fail with 401.

#### Email Removed from Public Profile (#2)
**Affects:** `GET /users/:username`, `GET /api/v1/profiles/:username`

The `email` field is no longer included in public profile responses. It's still available in the authenticated `GET /auth/me` response (`profile_data`).

**Frontend must:** Remove any display of `email` from public profile views, or source it from the authenticated user's own profile data only.

### New Error Responses (should handle gracefully)

#### Rate Limiting on Login (#4)
**Affects:** `POST /login`, `POST /auth/refresh`

Returns HTTP 429 when limits are exceeded:
- Login: 5 attempts per email per 15 min, 20 per IP per 15 min
- Refresh: 30 per IP per 15 min

```json
{ "error": "Too many login attempts. Please try again later." }
```

**Frontend should:** Show a user-friendly "too many attempts" message and disable the login button temporarily.

#### Scrobble History Now Private (#5)
**Affects:** `GET /users/:id/scrobbles`

Returns HTTP 403 unless the authenticated user is viewing their own scrobbles.

**Frontend should:** Remove or hide the scrobble history on other users' profiles, or handle the 403 gracefully.

### Non-Breaking Additions (recommended to adopt)

#### Password Reset Returns Refresh Token (#7)
**Affects:** `POST /password_reset`

Response now includes `refresh_token` in addition to `auth_token`:

```json
{
  "auth_token": "...",
  "refresh_token": "...",
  "message": "Password has been reset successfully"
}
```

**Frontend should:** Store the `refresh_token` from the password reset response to establish a full session. Without this, the user would need to log in again when the access token expires.

---

## Priority Summary

### Immediate Action Required

| #   | Category | Issue                                             |
| --- | -------- | ------------------------------------------------- |
| ~~1~~   | ~~Security~~ | ~~Firebase private key on disk - rotate immediately~~ DONE |
| ~~2~~   | ~~Security~~ | ~~Email exposed in public profile endpoint~~ DONE |
| ~~8~~   | ~~Security~~ | ~~JWT algorithm not specified in decode~~ DONE             |
| ~~38~~  | ~~Quality~~  | ~~Missing mailer views~~ NOT AN ISSUE (all views exist)     |

### High Priority

| #     | Category | Issue                                              |
| ----- | -------- | -------------------------------------------------- |
| ~~4~~     | ~~Security~~ | ~~No rate limiting on login~~ DONE                          |
| ~~5~~     | ~~Security~~ | ~~Scrobble history publicly accessible~~ DONE               |
| ~~6~~     | ~~Security~~ | ~~Refresh token rotation disabled~~ DONE                    |
| ~~7~~     | ~~Security~~ | ~~Password reset doesn't revoke sessions~~ DONE             |
| ~~3~~     | ~~Security~~ | ~~`permit!` bypasses strong params~~ DONE               |
| ~~26~~    | ~~Perf~~     | ~~Production jobs lost on restart (`:async` adapter)~~ DONE |
| 27    | Perf     | ActiveStorage `:local` in production (infrastructure change)               |
| ~~17-18~~ | ~~Perf~~     | ~~N+1 queries in serializers~~ DONE                         |
| ~~22~~    | ~~Perf~~     | ~~Missing trigram indexes for search~~ DONE                 |
| ~~--~~    | ~~Perf~~     | ~~All missing pagination endpoints~~ DONE                   |
| ~~--~~    | ~~Perf~~     | ~~All missing counter caches~~ DONE                         |

### Medium Priority

| #     | Category | Issue                                                                 |
| ----- | -------- | --------------------------------------------------------------------- |
| ~~9-12~~  | ~~Security~~ | ~~Denylist serializer, admin escalation, upload validation, constantize~~ DONE |
| 28-29 | Perf     | HTTP caching, image variants                                          |
| ~~33-35~~ | ~~Quality~~  | ~~Code duplication (11x url helper, query service, link builders)~~ DONE   |
| 42    | Quality  | Two competing error handler concerns (standardize format)             |

### Low Priority / Housekeeping

| #     | Category | Issue                                                       |
| ----- | -------- | ----------------------------------------------------------- |
| ~~13-16~~ | ~~Security~~ | ~~Bare rescue, CORS localhost, param filtering, timing attack~~ DONE |
| ~~36-37~~ | ~~Quality~~  | ~~Self-follow, extra UPDATE on create~~ DONE                         |
| ~~39-41~~ | ~~Quality~~  | ~~Unused gems, version pins, duplicate rack-cors~~ DONE              |
| --    | Quality  | Test coverage                                               |
