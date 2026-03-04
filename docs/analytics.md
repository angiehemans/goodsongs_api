# GoodSongs: Page Analytics & Dashboard — Product Requirements Document

## Overview

GoodSongs needs a lightweight, privacy-friendly analytics system that tracks page views, post views, and traffic sources for Blogger and Band accounts. This data powers a user-facing dashboard where bloggers and bands can see real metrics about their audience — who's reading, where they're coming from, and what content performs best.

The system is built entirely in-house using the existing Rails API and PostgreSQL database, with no external analytics scripts or third-party dependencies. This keeps pages fast, respects visitor privacy, and gives GoodSongs full ownership of the data.

---

## Goals

1. Track page views, unique visitors, and traffic sources for all public-facing Blogger and Band content
2. Provide a clean, actionable dashboard for paid users to understand their audience
3. Zero impact on page load performance
4. Privacy-friendly by default — no cookies, no PII stored, GDPR-safe
5. Scale gracefully from low volume to thousands of daily views without architectural changes

---

## Non-Goals

- Full product analytics (funnels, retention, A/B testing) — this is audience analytics for content creators, not internal product telemetry
- Real-time live visitor counts — near-real-time (minutes) is sufficient
- Bot/crawler filtering at launch — can be added later with user-agent parsing
- Revenue attribution or conversion tracking

---

## Ability Gating

Analytics access is controlled through the roles, plans, and abilities system defined in the Roles, Plans & Abilities PRD.

| Ability Key      | Description                    | Plans                                                |
| ---------------- | ------------------------------ | ---------------------------------------------------- |
| `view_analytics` | Access the analytics dashboard | `blogger`, `blogger_pro`, `band_starter`, `band_pro` |

Users without this ability see an upgrade prompt in place of the dashboard.

**Important:** Tracking happens on all public content regardless of the owner's plan. A Blogger on the base tier can see their analytics. A Band on the free tier accumulates data in the background — when they upgrade, their historical analytics are already there. This creates a powerful upgrade incentive.

---

## Tracking Architecture

### Frontend Beacon

Every public page (blog posts, band profiles, events, custom pages) fires a single non-blocking request on load using the Beacon API.

```typescript
function trackView(type: string, id: string) {
  const payload = JSON.stringify({
    type, // "BlogPost", "BandProfile", "Event", "CustomPage"
    id, // Record ID
    path: window.location.pathname,
    referrer: document.referrer,
  });

  navigator.sendBeacon("/api/v1/track", payload);
}
```

**Why `sendBeacon`:**

- Non-blocking — does not delay page rendering or interaction
- Fires reliably even if the user navigates away immediately
- No response handling needed — fire and forget
- Supported in all modern browsers

**Fallback:** For the rare browser that doesn't support `sendBeacon`, fall back to a standard `fetch` with `keepalive: true`. Do not fall back to synchronous XHR.

```typescript
function trackView(type: string, id: string) {
  const payload = JSON.stringify({
    type,
    id,
    path: window.location.pathname,
    referrer: document.referrer,
  });

  if (navigator.sendBeacon) {
    navigator.sendBeacon("/api/v1/track", payload);
  } else {
    fetch("/api/v1/track", {
      method: "POST",
      body: payload,
      headers: { "Content-Type": "application/json" },
      keepalive: true,
    });
  }
}
```

### Tracking API Endpoint

```
POST /api/v1/track
```

This endpoint is unauthenticated — it must accept requests from anonymous visitors. It should be rate-limited to prevent abuse (see Security section).

**Request body:**

```json
{
  "type": "BlogPost",
  "id": "456",
  "path": "/blog/why-deftones-hit-different",
  "referrer": "https://www.google.com/search?q=deftones+blog"
}
```

**Server-side enrichment:**

The endpoint enriches each request with data derived server-side, not sent from the client:

| Field             | Source                     | Purpose                               |
| ----------------- | -------------------------- | ------------------------------------- |
| `referrer_source` | Parsed from referrer URL   | Categorized traffic source            |
| `session_id`      | Cookie or generated UUID   | Unique visitor tracking without login |
| `ip_hash`         | SHA-256 of request IP      | Privacy-safe deduplication and geo    |
| `user_agent`      | Request header             | Device/browser breakdown              |
| `country`         | GeoIP lookup on request IP | Geographic distribution               |
| `device_type`     | Parsed from user agent     | Mobile vs desktop vs tablet           |

**Referrer source parsing:**

```ruby
def parse_source(referrer)
  return "direct" if referrer.blank?

  host = URI.parse(referrer).host&.downcase rescue nil
  return "direct" if host.nil?

  case host
  when /google\./        then "google"
  when /bing\./          then "bing"
  when /duckduckgo\./    then "duckduckgo"
  when /twitter\.com|t\.co|x\.com/ then "twitter"
  when /instagram\.com/  then "instagram"
  when /facebook\.com/   then "facebook"
  when /threads\.net/    then "threads"
  when /reddit\.com/     then "reddit"
  when /youtube\.com/    then "youtube"
  when /tiktok\.com/     then "tiktok"
  when /substack\.com/   then "substack"
  when /bandcamp\.com/   then "bandcamp"
  when /goodsongs\./     then "goodsongs"
  when /last\.fm/        then "lastfm"
  else "other"
  end
end
```

The `goodsongs` source is particularly important — it shows bloggers and bands how much traffic comes from within the GoodSongs network (recommendations, follows, discovery), which reinforces the platform's value.

---

## Data Model

### `page_views` Table

| Column            | Type     | Nullable | Description                                                                       |
| ----------------- | -------- | -------- | --------------------------------------------------------------------------------- |
| `id`              | bigint   | no       | Primary key                                                                       |
| `viewable_type`   | string   | no       | Polymorphic type (BlogPost, BandProfile, Event, CustomPage)                       |
| `viewable_id`     | bigint   | no       | Polymorphic ID                                                                    |
| `owner_id`        | bigint   | no       | Foreign key to users — the content owner, denormalized for fast dashboard queries |
| `referrer`        | string   | yes      | Raw referrer URL                                                                  |
| `referrer_source` | string   | no       | Parsed category (google, direct, instagram, goodsongs, etc.)                      |
| `path`            | string   | no       | URL path visited                                                                  |
| `session_id`      | string   | no       | Anonymous session identifier                                                      |
| `ip_hash`         | string   | no       | SHA-256 hashed IP address                                                         |
| `user_agent`      | string   | yes      | Raw user agent string                                                             |
| `device_type`     | string   | no       | Parsed: mobile, desktop, tablet                                                   |
| `country`         | string   | yes      | Two-letter country code from GeoIP                                                |
| `created_at`      | datetime | no       | Timestamp of the view                                                             |

**Why `owner_id` is denormalized:** The dashboard always queries "show me analytics for all my content." Without `owner_id`, every query would need to join through the polymorphic viewable to find the owner. Denormalizing this makes the most common query path fast and simple.

### Indexes

```ruby
add_index :page_views, [:owner_id, :created_at]
add_index :page_views, [:viewable_type, :viewable_id, :created_at]
add_index :page_views, [:owner_id, :referrer_source, :created_at]
add_index :page_views, :created_at
```

The first index powers the main dashboard. The second powers individual post/page analytics. The third powers the traffic sources breakdown. The fourth supports cleanup jobs.

### Migration

```ruby
class CreatePageViews < ActiveRecord::Migration[7.1]
  def change
    create_table :page_views do |t|
      t.string :viewable_type, null: false
      t.bigint :viewable_id, null: false
      t.bigint :owner_id, null: false
      t.string :referrer
      t.string :referrer_source, null: false, default: "direct"
      t.string :path, null: false
      t.string :session_id, null: false
      t.string :ip_hash, null: false
      t.string :user_agent
      t.string :device_type, null: false, default: "desktop"
      t.string :country
      t.datetime :created_at, null: false
    end

    add_index :page_views, [:owner_id, :created_at]
    add_index :page_views, [:viewable_type, :viewable_id, :created_at]
    add_index :page_views, [:owner_id, :referrer_source, :created_at]
    add_index :page_views, :created_at
  end
end
```

Note: This table intentionally does not have `updated_at`. Page views are write-once, never updated.

---

## Session Management

To count unique visitors without requiring login or using invasive tracking cookies, the system uses a lightweight session approach.

**On first visit:** If no `gs_session` cookie exists, the tracking endpoint generates a UUID and sets it as a first-party cookie with a 24-hour expiration. This means a visitor who returns the next day counts as a new unique — which is standard for privacy-friendly analytics.

**On subsequent visits (same day):** The existing `gs_session` cookie is sent with the beacon, allowing deduplication.

**Why not fingerprinting:** Browser fingerprinting is invasive and increasingly blocked. A simple session cookie with short expiry is transparent, privacy-friendly, and sufficient for the metrics bloggers and bands actually need.

```ruby
def session_id
  cookies[:gs_session] ||= {
    value: SecureRandom.uuid,
    expires: 24.hours.from_now,
    httponly: true,
    same_site: :lax
  }
  cookies[:gs_session]
end
```

---

## Dashboard Metrics

The analytics dashboard surfaces five core metric groups. All queries filter by `owner_id` matching the current user.

### 1. Overview Cards

Top-level summary stats shown as prominent numbers at the top of the dashboard.

| Metric          | Calculation                        | Default Period |
| --------------- | ---------------------------------- | -------------- |
| Total Views     | Count of page_views                | Last 30 days   |
| Unique Visitors | Distinct session_id count          | Last 30 days   |
| Top Post        | viewable with highest view count   | Last 30 days   |
| Top Source      | referrer_source with highest count | Last 30 days   |

### 2. Views Over Time (Line Chart)

A time-series chart showing views per day over the selected period. Supports toggling between total views and unique visitors.

```ruby
PageView.where(owner_id: current_user.id)
        .where(created_at: period_start..period_end)
        .group_by_day(:created_at)
        .count
```

Uses the `groupdate` gem for clean time-series grouping.

### 3. Traffic Sources (Pie/Bar Chart)

Breakdown of where visitors are coming from.

```ruby
PageView.where(owner_id: current_user.id)
        .where(created_at: period_start..period_end)
        .group(:referrer_source)
        .order(count_all: :desc)
        .count
```

Display as a horizontal bar chart or pie chart. Highlight the `goodsongs` source distinctly — this reinforces the platform's value proposition to paying users.

### 4. Content Performance (Table)

Ranked list of the user's content by view count.

| Column          | Data                                    |
| --------------- | --------------------------------------- |
| Title           | Post/page title (linked)                |
| Views           | Total view count                        |
| Unique Visitors | Distinct sessions                       |
| Avg. Time       | Future enhancement                      |
| Top Source      | Primary traffic source for this content |

```ruby
PageView.where(owner_id: current_user.id)
        .where(created_at: period_start..period_end)
        .group(:viewable_type, :viewable_id)
        .order(count_all: :desc)
        .count
```

### 5. Geographic Distribution (Table or Map)

Where visitors are located by country.

```ruby
PageView.where(owner_id: current_user.id)
        .where(created_at: period_start..period_end)
        .where.not(country: nil)
        .group(:country)
        .order(count_all: :desc)
        .limit(20)
        .count
```

Display as a ranked list with country flags. A map visualization is a future enhancement.

### 6. Device Breakdown (Donut Chart)

Mobile vs desktop vs tablet split.

```ruby
PageView.where(owner_id: current_user.id)
        .where(created_at: period_start..period_end)
        .group(:device_type)
        .count
```

### Date Range Selector

All dashboard views support a date range selector with presets:

- Today
- Last 7 days
- Last 30 days (default)
- Last 90 days
- This month
- Last month
- Custom range

---

## Dashboard API Endpoints

The dashboard is powered by a set of API endpoints that return pre-computed metrics. All endpoints require authentication and the `view_analytics` ability.

```
GET /api/v1/analytics/overview?period=30d
GET /api/v1/analytics/views_over_time?period=30d&granularity=day
GET /api/v1/analytics/traffic_sources?period=30d
GET /api/v1/analytics/content_performance?period=30d&page=1
GET /api/v1/analytics/geography?period=30d
GET /api/v1/analytics/devices?period=30d
```

**Example response for `/api/v1/analytics/overview`:**

```json
{
  "period": "30d",
  "total_views": 2847,
  "unique_visitors": 1923,
  "top_post": {
    "id": 456,
    "title": "Why Deftones Hit Different 25 Years Later",
    "views": 312
  },
  "top_source": {
    "source": "google",
    "count": 1204
  },
  "views_change_pct": 12.5,
  "visitors_change_pct": 8.3
}
```

The `_change_pct` fields compare the current period to the previous equivalent period (e.g., last 30 days vs the 30 days before that), giving users a sense of trending direction.

---

## Privacy Requirements

Analytics must be privacy-friendly by default. This is both an ethical choice and a practical one — it avoids GDPR/CCPA compliance complexity.

| Requirement            | Implementation                                                               |
| ---------------------- | ---------------------------------------------------------------------------- |
| No PII stored          | IP addresses are hashed (SHA-256), never stored raw                          |
| No third-party scripts | All tracking is first-party, no external dependencies                        |
| No cross-site tracking | Session cookie is first-party, short-lived, httponly                         |
| No fingerprinting      | Only standard session cookies for uniqueness                                 |
| Minimal cookie         | Single `gs_session` cookie, 24-hour expiry                                   |
| Data retention         | Raw page views retained for 12 months, then aggregated and purged            |
| No ad tracking         | No integration with ad networks or data brokers                              |
| Transparency           | Public-facing content should note "Analytics by GoodSongs" in privacy policy |

---

## Security & Abuse Prevention

### Rate Limiting

The tracking endpoint is unauthenticated and public, making it a target for abuse.

| Protection         | Implementation                                                         |
| ------------------ | ---------------------------------------------------------------------- |
| IP rate limit      | Max 100 tracking requests per IP per minute                            |
| Session rate limit | Max 10 views per session per page per hour (deduplication)             |
| Payload validation | Reject requests with invalid viewable_type or non-existent viewable_id |
| Size limit         | Reject request bodies over 1KB                                         |

### Bot Filtering

At launch, minimal bot filtering is acceptable. Phase 2 should add:

- User-agent blocklist for known bots and crawlers
- Referer spam blocklist for known spam referrers
- Anomaly detection for sudden traffic spikes from single IPs

### Self-View Exclusion

Content owners should not inflate their own view counts. If the tracking request comes from an authenticated session where the user is the content owner, skip recording the view.

---

## Data Retention & Aggregation

Raw `page_views` rows are retained for **12 months**. After 12 months, a background job aggregates daily totals into a `page_view_aggregates` table and purges the raw rows. This keeps the raw table manageable while preserving long-term trend data.

### `page_view_aggregates` Table

| Column            | Type    | Description                |
| ----------------- | ------- | -------------------------- |
| `id`              | bigint  | Primary key                |
| `viewable_type`   | string  | Polymorphic type           |
| `viewable_id`     | bigint  | Polymorphic ID             |
| `owner_id`        | bigint  | Content owner              |
| `date`            | date    | Aggregation date           |
| `total_views`     | integer | Total views that day       |
| `unique_visitors` | integer | Distinct sessions that day |
| `referrer_source` | string  | Traffic source             |
| `device_type`     | string  | Device category            |
| `country`         | string  | Country code               |

This table is much smaller than raw page_views and supports the same dashboard queries for historical data. The dashboard should seamlessly query both tables — raw for recent data, aggregates for older data.

### Cleanup Job

```ruby
# Run nightly
class AggregatePageViewsJob < ApplicationJob
  def perform
    cutoff = 12.months.ago.beginning_of_day

    PageView.where("created_at < ?", cutoff)
            .group(:viewable_type, :viewable_id, :owner_id,
                   :referrer_source, :device_type, :country)
            .group_by_day(:created_at)
            .select(
              "viewable_type, viewable_id, owner_id,
               referrer_source, device_type, country,
               DATE(created_at) as date,
               COUNT(*) as total_views,
               COUNT(DISTINCT session_id) as unique_visitors"
            )
            .each do |row|
              PageViewAggregate.find_or_create_by!(
                viewable_type: row.viewable_type,
                viewable_id: row.viewable_id,
                owner_id: row.owner_id,
                date: row.date,
                referrer_source: row.referrer_source,
                device_type: row.device_type,
                country: row.country
              ).update!(
                total_views: row.total_views,
                unique_visitors: row.unique_visitors
              )
            end

    PageView.where("created_at < ?", cutoff).delete_all
  end
end
```

---

## Scaling Path

The system is designed to scale progressively without upfront over-engineering.

### Stage 1: Direct Writes (Launch)

Write every page view directly to PostgreSQL. This handles up to roughly 100 requests/second, which is well beyond what GoodSongs needs at launch.

### Stage 2: Buffered Writes

When write volume causes noticeable database load, introduce a Redis buffer. Tracking requests write to a Redis list, and a background job flushes batches to PostgreSQL every 30–60 seconds.

```ruby
# Tracking endpoint writes to Redis
class Api::V1::TrackingController < ApplicationController
  def create
    REDIS.lpush("page_views:buffer", build_view_data.to_json)
    head :ok
  end
end

# Background job flushes to Postgres
class FlushPageViewsJob < ApplicationJob
  def perform
    batch = []
    while (raw = REDIS.lpop("page_views:buffer"))
      batch << JSON.parse(raw)
      break if batch.size >= 1000
    end

    PageView.insert_all(batch) if batch.any?
    FlushPageViewsJob.perform_later if REDIS.llen("page_views:buffer") > 0
  end
end
```

### Stage 3: Table Partitioning

When the `page_views` table exceeds ~50 million rows, partition by month using PostgreSQL's native partitioning. This makes cleanup jobs faster and keeps query performance consistent.

### Stage 4: Dedicated Analytics Store

If GoodSongs reaches a scale where analytics queries compete with application queries, move analytics to a read replica or a dedicated ClickHouse/TimescaleDB instance. This is unlikely to be needed before hundreds of thousands of active content creators.

---

## Dependencies

| Dependency                | Purpose                                            | Required                                 |
| ------------------------- | -------------------------------------------------- | ---------------------------------------- |
| `groupdate` gem           | Time-series grouping (group_by_day, group_by_week) | Yes                                      |
| `maxminddb` gem           | GeoIP lookup for country detection                 | Yes                                      |
| MaxMind GeoLite2 database | Free IP-to-country database                        | Yes (download and update monthly)        |
| `device_detector` gem     | User-agent parsing for device type                 | Yes                                      |
| Redis                     | Buffered writes (Stage 2 only)                     | No (already in stack for other features) |

---

## Implementation Status

### Implemented (Phase 1 & 2)

| Component | Status | Notes |
|-----------|--------|-------|
| `page_views` table | Done | Migration `20260227000001_create_page_views.rb` |
| `PageView` model | Done | `app/models/page_view.rb` |
| Tracking endpoint | Done | `POST /api/v1/track` |
| Session management | Done | `gs_session` cookie, 24-hour expiry |
| Referrer parsing | Done | `app/services/referrer_parser.rb` |
| Device detection | Done | `app/services/device_type_parser.rb` |
| GeoIP lookup | Done | `app/services/geoip_lookup.rb` |
| IP hashing | Done | SHA-256 with secret salt |
| Self-view exclusion | Done | Skips if authenticated owner |
| Rate limiting | Done | 100 req/min per IP |
| Deduplication | Done | Same session + page within 1 hour |
| Analytics controller | Done | 6 endpoints with ability gating |
| Blog dashboard endpoint | Done | `GET /api/v1/blog_dashboard` - comprehensive dashboard data |
| Period filtering | Done | 7d, 30d, 90d, custom |
| Period-over-period comparison | Done | In overview endpoint |

### Deferred

| Component | Status | Notes |
|-----------|--------|-------|
| Table partitioning | Deferred | Not needed until page_views exceeds 50M rows |
| Redis buffered writes | Deferred | Direct writes handle 100 req/s, sufficient for launch |
| Bot filtering | Deferred | Phase 4 enhancement, post-launch iteration |
| Referrer spam filtering | Deferred | Phase 4 enhancement, post-launch iteration |
| `page_view_aggregates` table | Deferred | Build when approaching 12 months of data |
| GeoIP auto-update job | Deferred | Manual monthly updates for now |

---

## API Reference

All analytics endpoints require authentication and the `view_analytics` ability.

### Tracking (Unauthenticated)

#### `POST /api/v1/track`

Record a page view. Unauthenticated, rate-limited to 100/min per IP.

**Request:**
```json
{
  "viewable_type": "post",
  "viewable_id": 123,
  "path": "/blogs/johndoe/my-post",
  "referrer": "https://google.com/search?q=music"
}
```

**Response:** `204 No Content`

| viewable_type | Description |
|---------------|-------------|
| `post` | Blog post |
| `band` | Band profile |
| `event` | Event page |

---

### Analytics Dashboard

All endpoints support `?period=` parameter: `7d`, `30d` (default), `90d`, or `custom` with `start_date` and `end_date`.

#### `GET /api/v1/analytics/overview`

Summary cards with period-over-period comparison.

**Response:**
```json
{
  "data": {
    "total_views": 2847,
    "total_views_change": 12.5,
    "unique_visitors": 1923,
    "unique_visitors_change": 8.3,
    "period": "30d",
    "start_date": "2026-01-28T00:00:00Z",
    "end_date": "2026-02-27T23:59:59Z"
  }
}
```

#### `GET /api/v1/analytics/views_over_time`

Time-series data for charting.

**Response:**
```json
{
  "data": {
    "views": [
      { "date": "2026-02-01", "views": 142 },
      { "date": "2026-02-02", "views": 156 }
    ],
    "period": "30d"
  }
}
```

#### `GET /api/v1/analytics/traffic_sources`

Breakdown by referrer source.

**Response:**
```json
{
  "data": {
    "sources": [
      { "source": "google", "views": 1204, "percentage": 42.3 },
      { "source": "direct", "views": 892, "percentage": 31.3 },
      { "source": "goodsongs", "views": 412, "percentage": 14.5 }
    ],
    "total": 2847,
    "period": "30d"
  }
}
```

#### `GET /api/v1/analytics/content_performance`

Top content ranked by views.

**Response:**
```json
{
  "data": {
    "content": [
      {
        "type": "post",
        "id": 456,
        "title": "Why Deftones Hit Different",
        "views": 312,
        "path": "/blogs/johndoe/why-deftones-hit-different"
      }
    ],
    "period": "30d"
  }
}
```

#### `GET /api/v1/analytics/geography`

Breakdown by country.

**Response:**
```json
{
  "data": {
    "countries": [
      { "country": "US", "views": 1523, "percentage": 53.5 },
      { "country": "GB", "views": 412, "percentage": 14.5 }
    ],
    "unknown": 203,
    "total": 2847,
    "period": "30d"
  }
}
```

#### `GET /api/v1/analytics/devices`

Breakdown by device type.

**Response:**
```json
{
  "data": {
    "devices": [
      { "device": "desktop", "views": 1821, "percentage": 64.0 },
      { "device": "mobile", "views": 923, "percentage": 32.4 },
      { "device": "tablet", "views": 103, "percentage": 3.6 }
    ],
    "total": 2847,
    "period": "30d"
  }
}
```

---

### Blog Dashboard (Comprehensive)

#### `GET /api/v1/blog_dashboard`

Comprehensive blog dashboard combining totals, analytics, content, and engagement metrics in a single request. Requires authentication.

**Response:**
```json
{
  "totals": {
    "page_views": 12500,
    "posts": 42,
    "recommendations": 156,
    "followers": 892,
    "comments": 234
  },
  "page_views_over_time": [
    { "date": "2026-01-01", "views": 125 },
    { "date": "2026-01-02", "views": 143 }
  ],
  "traffic_sources": [
    { "source": "google", "views": 4500, "percentage": 36.0 },
    { "source": "direct", "views": 3200, "percentage": 25.6 },
    { "source": "goodsongs", "views": 2100, "percentage": 16.8 },
    { "source": "twitter", "views": 1500, "percentage": 12.0 }
  ],
  "recent_posts": [
    {
      "id": 123,
      "title": "Why Deftones Hit Different",
      "slug": "why-deftones-hit-different",
      "excerpt": "A deep dive into the sonic textures...",
      "status": "published",
      "featured": true,
      "publish_date": "2026-02-20T12:00:00Z",
      "created_at": "2026-02-19T10:30:00Z",
      "likes_count": 45,
      "comments_count": 12
    }
  ],
  "recent_notifications": [
    {
      "id": 456,
      "type": "post_like",
      "read": false,
      "actor": {
        "id": 789,
        "username": "musicfan42",
        "display_name": "Music Fan",
        "profile_image_url": "https://..."
      },
      "created_at": "2026-02-27T08:15:00Z"
    }
  ],
  "follower_growth": [
    { "week": "2025-12-01", "new_followers": 12 },
    { "week": "2025-12-08", "new_followers": 8 },
    { "week": "2025-12-15", "new_followers": 15 }
  ],
  "top_performing_posts": [
    {
      "id": 123,
      "title": "Why Deftones Hit Different",
      "slug": "why-deftones-hit-different",
      "excerpt": "A deep dive into the sonic textures...",
      "publish_date": "2026-02-20T12:00:00Z",
      "views": 1250,
      "likes": 45,
      "comments": 12,
      "engagement_score": 1376
    }
  ]
}
```

| Field | Description |
|-------|-------------|
| `totals.page_views` | Total page views across all user's content (all time) |
| `totals.posts` | Total number of posts created |
| `totals.recommendations` | Total number of reviews/recommendations created |
| `totals.followers` | Current follower count |
| `totals.comments` | Total comments received on posts and recommendations |
| `page_views_over_time` | Daily page views for the last 60 days |
| `traffic_sources` | Referrer source breakdown for last 60 days with percentages |
| `recent_posts` | 5 most recent posts with engagement metrics |
| `recent_notifications` | 5 most recent notifications with actor details |
| `follower_growth` | Weekly new follower counts for the last 3 months |
| `top_performing_posts` | 5 top published posts by engagement score |

**Engagement Score Calculation:**
```
engagement_score = views + (likes × 2) + (comments × 3)
```

Interactions are weighted higher than views to surface truly engaging content.

---

## Implementation Phases

### Phase 1: Core Tracking (Week 1) ✅ COMPLETE

- Create `page_views` table and migration
- Build tracking API endpoint with referrer parsing, IP hashing, and session management
- Add `sendBeacon` tracking call to all public pages (blog posts, band profiles, events, custom pages)
- Add self-view exclusion
- Add rate limiting to tracking endpoint

### Phase 2: Dashboard API (Week 2) ✅ COMPLETE

- Build analytics controller with ability gating
- Implement overview, views_over_time, traffic_sources, content_performance, geography, and devices endpoints
- Add date range filtering with period presets
- Add period-over-period comparison calculations

### Phase 3: Dashboard UI (Week 2–3)

- Build dashboard page with overview cards
- Add views over time line chart
- Add traffic sources chart
- Add content performance table with sorting
- Add geographic distribution table
- Add device breakdown chart
- Add date range selector
- Add upgrade prompt for users without `view_analytics` ability

### Phase 4: Polish & Ops (Week 3–4) — DEFERRED

- Add bot filtering (user-agent blocklist) — *Deferred for post-launch iteration*
- Add referrer spam filtering — *Deferred for post-launch iteration*
- Set up data retention job and `page_view_aggregates` table — *Deferred until approaching 12 months of data*
- Add GeoIP database auto-update job — *Manual updates for now*
- Load test tracking endpoint
- Monitor page_views table growth and index performance

---

## Success Criteria

- Tracking adds zero perceptible latency to page loads
- Dashboard loads in under 2 seconds for users with up to 100,000 page views
- No PII is stored in the page_views table
- Users on free plans accumulate analytics data that becomes visible on upgrade
- The `goodsongs` traffic source is prominently surfaced, reinforcing platform value
- Feature gating works correctly through the abilities system with contextual upgrade prompts
