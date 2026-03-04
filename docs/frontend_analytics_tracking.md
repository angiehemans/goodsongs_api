# Frontend Analytics Tracking Implementation

This guide covers how to implement page view tracking on the frontend for blog posts, band profiles, and events.

---

## Overview

The tracking system uses a simple beacon endpoint that records page views. The backend handles:
- Session management (via `gs_session` cookie)
- Referrer parsing
- Device detection
- Country lookup
- Self-view exclusion (owners don't inflate their own stats)
- Deduplication (same session + page within 1 hour)

---

## Tracking Endpoint

```
POST /api/v1/track
```

**Authentication:** None required (public endpoint)

**Rate Limit:** 100 requests/minute per IP

---

## Request Payload

```typescript
interface TrackingPayload {
  viewable_type: 'post' | 'band' | 'event';
  viewable_id: number;
  path: string;           // Current page path
  referrer?: string;      // document.referrer (optional)
}
```

### Example

```json
{
  "viewable_type": "post",
  "viewable_id": 123,
  "path": "/blogs/johndoe/my-awesome-post",
  "referrer": "https://google.com/search?q=music+blog"
}
```

---

## Response

| Status | Meaning |
|--------|---------|
| `204 No Content` | Success (view recorded or skipped) |
| `404 Not Found` | Invalid viewable_type or viewable_id |
| `429 Too Many Requests` | Rate limited |

The endpoint always returns `204` for valid content, even if the view was skipped due to:
- Self-view (authenticated owner viewing their own content)
- Duplicate view (same session + page within 1 hour)

---

## Implementation

### Basic Tracking Function

```typescript
// lib/analytics.ts

const API_BASE = process.env.NEXT_PUBLIC_API_URL || 'http://localhost:3000';

interface TrackPageViewParams {
  viewableType: 'post' | 'band' | 'event';
  viewableId: number;
  path: string;
}

export async function trackPageView({ viewableType, viewableId, path }: TrackPageViewParams): Promise<void> {
  try {
    await fetch(`${API_BASE}/api/v1/track`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      credentials: 'include', // Important: sends gs_session cookie
      body: JSON.stringify({
        viewable_type: viewableType,
        viewable_id: viewableId,
        path: path,
        referrer: document.referrer || undefined,
      }),
    });
  } catch (error) {
    // Silently fail - analytics should never break the app
    console.debug('Analytics tracking failed:', error);
  }
}
```

### React Hook

```typescript
// hooks/usePageTracking.ts

import { useEffect, useRef } from 'react';
import { trackPageView } from '@/lib/analytics';

interface UsePageTrackingParams {
  viewableType: 'post' | 'band' | 'event';
  viewableId: number | undefined;
  path: string;
}

export function usePageTracking({ viewableType, viewableId, path }: UsePageTrackingParams) {
  const tracked = useRef(false);

  useEffect(() => {
    // Only track once per mount, and only if we have an ID
    if (tracked.current || !viewableId) return;

    tracked.current = true;
    trackPageView({ viewableType, viewableId, path });
  }, [viewableType, viewableId, path]);
}
```

### Usage in Page Components

#### Blog Post Page

```tsx
// app/blogs/[username]/[slug]/page.tsx

'use client';

import { usePageTracking } from '@/hooks/usePageTracking';
import { usePathname } from 'next/navigation';

export default function BlogPostPage({ post }: { post: Post }) {
  const pathname = usePathname();

  usePageTracking({
    viewableType: 'post',
    viewableId: post.id,
    path: pathname,
  });

  return (
    <article>
      <h1>{post.title}</h1>
      {/* ... */}
    </article>
  );
}
```

#### Band Profile Page

```tsx
// app/bands/[slug]/page.tsx

'use client';

import { usePageTracking } from '@/hooks/usePageTracking';
import { usePathname } from 'next/navigation';

export default function BandProfilePage({ band }: { band: Band }) {
  const pathname = usePathname();

  usePageTracking({
    viewableType: 'band',
    viewableId: band.id,
    path: pathname,
  });

  return (
    <div>
      <h1>{band.name}</h1>
      {/* ... */}
    </div>
  );
}
```

#### Event Page

```tsx
// app/events/[id]/page.tsx

'use client';

import { usePageTracking } from '@/hooks/usePageTracking';
import { usePathname } from 'next/navigation';

export default function EventPage({ event }: { event: Event }) {
  const pathname = usePathname();

  usePageTracking({
    viewableType: 'event',
    viewableId: event.id,
    path: pathname,
  });

  return (
    <div>
      <h1>{event.name}</h1>
      {/* ... */}
    </div>
  );
}
```

---

## Important Notes

### 1. Credentials

Always include `credentials: 'include'` in the fetch call. This ensures the `gs_session` cookie is sent and received, enabling:
- Session-based deduplication
- Unique visitor counting

### 2. CORS

Ensure your API has CORS configured to allow credentials from your frontend domain:

```ruby
# config/initializers/cors.rb
Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins 'https://goodsongs.app', 'http://localhost:3001'
    resource '/api/v1/track',
      headers: :any,
      methods: [:post],
      credentials: true
  end
end
```

### 3. Self-View Exclusion

If the user is authenticated, include the auth token to enable self-view exclusion:

```typescript
export async function trackPageView({ viewableType, viewableId, path }: TrackPageViewParams): Promise<void> {
  const token = getAuthToken(); // Your auth token getter

  const headers: Record<string, string> = {
    'Content-Type': 'application/json',
  };

  // Include auth token if available (enables self-view exclusion)
  if (token) {
    headers['Authorization'] = `Bearer ${token}`;
  }

  try {
    await fetch(`${API_BASE}/api/v1/track`, {
      method: 'POST',
      headers,
      credentials: 'include',
      body: JSON.stringify({
        viewable_type: viewableType,
        viewable_id: viewableId,
        path: path,
        referrer: document.referrer || undefined,
      }),
    });
  } catch (error) {
    console.debug('Analytics tracking failed:', error);
  }
}
```

### 4. Don't Block Rendering

Analytics should never slow down or break your app:
- Fire and forget (don't await in render path)
- Catch all errors silently
- Use `console.debug` for logging (hidden in production)

### 5. SPA Navigation

The hook handles initial page load. For SPA navigation where the component doesn't remount, you may need to track on route change:

```typescript
// For Next.js App Router
'use client';

import { useEffect } from 'react';
import { usePathname } from 'next/navigation';
import { trackPageView } from '@/lib/analytics';

export function useRouteTracking(viewableType: 'post' | 'band' | 'event', viewableId: number) {
  const pathname = usePathname();

  useEffect(() => {
    trackPageView({ viewableType, viewableId, path: pathname });
  }, [pathname, viewableType, viewableId]);
}
```

---

## Testing

### Verify Tracking Works

1. Open browser DevTools > Network tab
2. Visit a blog post / band / event page
3. Look for `POST /api/v1/track` request
4. Should return `204 No Content`

### Check Cookie

After the first request, you should see a `gs_session` cookie set with a UUID value.

### Verify in Database

```bash
bin/rails runner "puts PageView.last(5).map { |pv| [pv.id, pv.viewable_type, pv.path, pv.referrer_source].join(' | ') }"
```

---

## Summary

1. Call `POST /api/v1/track` on page load
2. Include `credentials: 'include'` for session cookie
3. Optionally include auth token for self-view exclusion
4. Fire and forget - don't block rendering
5. The backend handles everything else (dedup, device detection, geo, etc.)
