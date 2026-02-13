# Dashboard API Optimization Plan

## Current State Analysis

### API Calls on Dashboard Load

| Endpoint | Status | Time | Issue |
|----------|--------|------|-------|
| `profile` | 304 | 65ms | OK |
| `unread_count` | 304 | 62ms | **Called 4+ times!** |
| `angie` (user profile) | 200 | **1.43s** | Very slow |
| `notifications` | 200 | 279ms | OK |
| `discover` | 200 | 321ms | OK |
| `settings` | 200 | 338ms | OK |
| `admin` | 200 | 311ms | OK |
| `following?page=1` | 304 | 296ms | OK |
| `user` (reviews/user) | 304 | 185ms | OK |
| `recently-played` | 200 | 196ms | OK |
| `followers` | 304 | 315ms | OK |
| `following` | 304 | 346ms | OK |
| `lizzieandromeda` | 200 | **998ms** | Slow user fetch |
| `38` (review/band?) | 200 | **1.17s** | Very slow |
| `shyeye` | 200 | **1.17s** | Very slow |
| `37` (review/band?) | 200 | **1.17s** | Very slow |
| `ivri` | 200 | **1.01s** | Slow user fetch |

**Total: 17+ API calls, ~10+ seconds cumulative**

---

## Identified Issues

### 1. Duplicate API Calls
**Problem**: `unread_count` called 4+ times on same page load

**Cause**: Multiple components independently fetching the same data

**Solution**:
- Frontend: Deduplicate with React Query/SWR or shared state
- Backend: No changes needed (already fast at 62-71ms)

---

### 2. Slow User Profile Fetches (1-1.5s each)
**Problem**: Individual user profiles (`angie`, `lizzieandromeda`, `shyeye`, `ivri`) taking 1+ second each

**Cause**: Likely N+1 queries or expensive computations per user

**Backend Investigation Needed**:
```ruby
# Check GET /users/:username endpoint
# Look for:
# - N+1 queries (reviews, bands, followers)
# - Expensive counts computed per request
# - Missing database indexes
```

**Potential Fixes**:
- Add eager loading for associations
- Cache follower/following counts on user record
- Add database indexes on frequently queried columns
- Consider pagination for user's reviews in profile

---

### 3. Slow Review/Band Fetches by ID (1+ second)
**Problem**: Fetches for `38` and `37` (likely review or band IDs) taking 1+ second

**Cause**: Similar to user profiles - likely N+1 or missing indexes

**Backend Investigation Needed**:
```ruby
# Check GET /reviews/:id and GET /bands/:slug endpoints
# Look for expensive joins/includes
```

---

### 4. Too Many Separate API Calls
**Problem**: Dashboard requires 17+ separate HTTP requests

**Cause**: Fine-grained endpoints designed for flexibility, not dashboard efficiency

**Solution Options**:

#### Option A: Combined Dashboard Endpoint (Recommended)
Create a single endpoint that returns all dashboard data:

```ruby
# GET /dashboard
{
  "profile": { ... },
  "unread_count": 5,
  "recent_reviews": [ ... ],
  "recently_played": [ ... ],
  "followers_count": 25,
  "following_count": 12,
  "feed_preview": [ ... ]  # First 5 items
}
```

**Pros**: Single request, server can optimize queries
**Cons**: Less flexible, more coupling

#### Option B: GraphQL
Allow frontend to request exactly what it needs in one query

**Pros**: Very flexible, reduces over-fetching
**Cons**: Significant implementation effort

#### Option C: Keep Separate + Optimize Individual Endpoints
Focus on making each endpoint faster (<100ms target)

**Pros**: Maintains current architecture
**Cons**: Still many HTTP requests

---

## Optimization Plan

### Phase 1: Quick Wins (Backend - 1 day)

#### 1.1 Add Database Indexes
```ruby
# migration
add_index :reviews, [:user_id, :created_at], order: { created_at: :desc }
add_index :follows, [:followed_id, :created_at]
add_index :follows, [:follower_id, :created_at]
add_index :notifications, [:user_id, :read, :created_at]
```

#### 1.2 Cache Counts on User Model
```ruby
# Add counter caches
add_column :users, :followers_count, :integer, default: 0
add_column :users, :following_count, :integer, default: 0
add_column :users, :reviews_count, :integer, default: 0

# Update Follow model
belongs_to :follower, class_name: 'User', counter_cache: :following_count
belongs_to :followed, class_name: 'User', counter_cache: :followers_count
```

#### 1.3 Eager Loading in User Profile
```ruby
# In users_controller.rb
def profile_by_username
  @user = User.includes(:bands, :reviews => [:band])
              .find_by!(username: params[:username])
end
```

---

### Phase 2: Combined Dashboard Endpoint (Backend - 2 days)

#### 2.1 Create Dashboard Controller
```ruby
# app/controllers/dashboard_controller.rb
class DashboardController < ApplicationController
  def show
    json_response({
      profile: UserSerializer.profile_data(current_user),
      unread_count: current_user.notifications.unread.count,
      recent_reviews: fetch_recent_reviews,
      recently_played: fetch_recently_played,
      following_feed_preview: fetch_feed_preview
    })
  end

  private

  def fetch_recent_reviews
    current_user.reviews.recent.limit(5).map do |review|
      ReviewSerializer.summary(review)
    end
  end

  def fetch_recently_played
    RecentlyPlayedService.new(current_user).fetch(limit: 10)
  end

  def fetch_feed_preview
    QueryService.following_feed(current_user, page: 1, per_page: 5)
                .map { |r| ReviewSerializer.full(r, current_user: current_user) }
  end
end
```

#### 2.2 Add Route
```ruby
get '/dashboard', to: 'dashboard#show'
```

---

### Phase 3: Frontend Deduplication (Frontend - 1 day)

#### 3.1 Deduplicate unread_count
```typescript
// Use React Query or SWR with shared key
const { data: unreadCount } = useQuery({
  queryKey: ['unread_count'],
  queryFn: fetchUnreadCount,
  staleTime: 30000, // 30 seconds
});
```

#### 3.2 Prefetch on Hover
```typescript
// Prefetch user profiles when hovering over username
onMouseEnter={() => {
  queryClient.prefetchQuery(['user', username], () => fetchUser(username))
}}
```

---

### Phase 4: Advanced Caching (Backend - 2 days)

#### 4.1 HTTP Caching Headers
```ruby
# For data that rarely changes
def profile
  expires_in 5.minutes, public: false
  # ...
end

# For frequently accessed public data
def show_band
  expires_in 1.hour, public: true
  # ...
end
```

#### 4.2 Redis Caching for Expensive Queries
```ruby
def following_feed(user, page:, per_page:)
  cache_key = "feed:#{user.id}:#{page}:#{per_page}"

  Rails.cache.fetch(cache_key, expires_in: 2.minutes) do
    # expensive query
  end
end
```

---

## Success Metrics

| Metric | Current | Target |
|--------|---------|--------|
| Total API calls | 17+ | 5-7 |
| Slowest endpoint | 1.43s | <300ms |
| Time to interactive | ~3s | <1s |
| Duplicate calls | 4+ | 0 |

---

## Priority Order

1. **P0**: Add missing database indexes (immediate impact)
2. **P0**: Fix N+1 queries in user profile endpoint
3. **P1**: Add counter caches for follower/following counts
4. **P1**: Create combined `/dashboard` endpoint
5. **P2**: Frontend deduplication of `unread_count`
6. **P2**: HTTP caching headers
7. **P3**: Redis caching for expensive queries

---

## Investigation Commands

```bash
# Check for slow queries in development
tail -f log/development.log | grep -E "SELECT|INSERT|UPDATE"

# Profile specific endpoint
curl -w "@curl-format.txt" -s "http://localhost:3000/users/angie" -H "Authorization: Bearer $TOKEN"

# Check for N+1 with bullet gem
# Add to Gemfile: gem 'bullet', group: :development
```

---

## Next Steps

1. [ ] Run `EXPLAIN ANALYZE` on slow queries to identify bottlenecks
2. [ ] Add bullet gem to detect N+1 queries
3. [ ] Implement Phase 1 (indexes + counter caches)
4. [ ] Measure improvement
5. [ ] Decide on combined endpoint vs optimize individual
