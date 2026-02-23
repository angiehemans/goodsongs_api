# Frontend Migration Guide: Roles, Plans & Abilities System

This guide helps frontend developers migrate from the legacy `account_type` system to the new Roles, Plans & Abilities (RBAC) system.

## Breaking Changes

### 1. `account_type` Replaced with `role`

The `account_type` field has been **removed** from all API responses. Use `role` instead.

**Before:**
```json
{
  "account_type": "fan"
}
```

**After:**
```json
{
  "role": "fan"
}
```

### 2. Role Values Changed

| Old `account_type` | New `role` |
|-------------------|------------|
| `"fan"` | `"fan"` |
| `"band"` | `"band"` |
| `"music_blogger"` | `"blogger"` |

### 3. New Fields in User Responses

All user profile responses now include:

```json
{
  "role": "fan",
  "plan": {
    "key": "fan_free",
    "name": "Fan Free"
  },
  "abilities": ["create_recommendation", "follow_users", "create_comments", "scrobble_lastfm"]
}
```

---

## Migration Steps

### Step 1: Find and Replace `account_type`

Search your codebase for all references to `account_type` and replace with `role`:

```bash
# Find all references
grep -r "account_type" src/

# Common patterns to update:
# user.account_type → user.role
# data.account_type → data.role
# account_type === "fan" → role === "fan"
# account_type === "music_blogger" → role === "blogger"
```

### Step 2: Update Type Definitions

**TypeScript types:**

```typescript
// OLD
interface User {
  account_type: 'fan' | 'band' | 'music_blogger';
}

// NEW
type Role = 'fan' | 'band' | 'blogger';

interface Plan {
  key: string;
  name: string;
}

interface User {
  role: Role;
  plan: Plan | null;
  abilities: string[];
}
```

### Step 3: Update Onboarding Flow

The onboarding endpoint now returns `role` instead of `account_type`:

**POST /onboarding/account-type**

Request (unchanged):
```json
{
  "account_type": "fan"
}
```

Response (changed):
```json
{
  "message": "Role set successfully",
  "role": "fan",
  "plan": {
    "key": "fan_free",
    "name": "Fan Free"
  },
  "onboarding_completed": false,
  "next_step": "complete_fan_profile"
}
```

### Step 4: Update Navigation Logic

Replace account_type checks with role checks:

```typescript
// OLD
if (user.account_type === 'fan') {
  return <FanNavigation />;
} else if (user.account_type === 'band') {
  return <BandNavigation />;
}

// NEW
switch (user.role) {
  case 'fan':
    return <FanNavigation />;
  case 'band':
    return <BandNavigation />;
  case 'blogger':
    return <BloggerNavigation />;
}
```

---

## Using Abilities for Feature Gating

### The New Approach

Instead of checking `account_type` to show/hide features, check the user's `abilities` array.

**Example: Create ability check hook**

```typescript
// hooks/useAbility.ts
import { useAuth } from './useAuth';

export function useAbility(abilityKey: string): boolean {
  const { user } = useAuth();
  return user?.abilities?.includes(abilityKey) ?? false;
}

export function useAbilities(abilityKeys: string[]): boolean {
  const { user } = useAuth();
  return abilityKeys.every(key => user?.abilities?.includes(key));
}
```

**Example: Using the hook**

```tsx
function PostEditor() {
  const canSchedule = useAbility('schedule_post');
  const canSellMerch = useAbility('manage_storefront');

  return (
    <div>
      <Editor />

      {canSchedule ? (
        <ScheduleButton />
      ) : (
        <UpgradePrompt ability="schedule_post" />
      )}

      {canSellMerch && <StorefrontSection />}
    </div>
  );
}
```

### Available Abilities

#### Content
| Ability | Description |
|---------|-------------|
| `create_recommendation` | Recommend songs to followers |
| `create_blog_post` | Write and publish blog posts |
| `attach_images` | Add images to blog posts |
| `attach_songs` | Embed songs with music player |
| `draft_posts` | Save posts as drafts |
| `schedule_post` | Schedule posts for future publication |
| `custom_pages` | Create About, Contact, etc. |
| `manage_tags` | Tag, genre, and category management |
| `rss_feed` | Public RSS feed for posts |
| `seo_controls` | Meta descriptions, OG images, canonical URLs |

#### Monetization
| Ability | Description |
|---------|-------------|
| `manage_storefront` | Sell merch and music |
| `accept_donations` | Accept reader donations |
| `manage_subscriptions` | Paid reader subscriptions |

#### Audience
| Ability | Description |
|---------|-------------|
| `follow_users` | Follow fans, bands, and bloggers |
| `create_comments` | Comment on posts and recommendations |
| `send_newsletter` | Mailing list management |

#### Social
| Ability | Description |
|---------|-------------|
| `auto_post_instagram` | Auto-post to Instagram |
| `auto_post_threads` | Auto-post to Threads |
| `instagram_display` | Display Instagram feed on profile |
| `share_playlists` | Share playlists across platforms |
| `scrobble_lastfm` | Last.fm scrobbling integration |

#### Analytics
| Ability | Description |
|---------|-------------|
| `view_analytics` | View page/profile analytics |

#### Band-specific
| Ability | Description |
|---------|-------------|
| `manage_band_profile` | Edit band profile and bio |
| `upload_music` | Upload tracks |
| `manage_events` | Create and manage events |
| `custom_design` | Customize profile appearance |

---

## Handling Upgrade Prompts

When a user tries to access a feature they don't have, the API returns a 403 response:

```json
{
  "error": "upgrade_required",
  "message": "This feature requires an upgrade.",
  "required_ability": "schedule_post",
  "upgrade_plan": "blogger_pro"
}
```

### Upgrade Prompt Component

```tsx
interface UpgradePromptProps {
  ability: string;
}

const abilityMessages: Record<string, string> = {
  schedule_post: "Schedule posts for the perfect publish time",
  manage_storefront: "Sell merch directly to your readers",
  send_newsletter: "Build and manage your mailing list",
  view_analytics: "See detailed insights about your content",
  auto_post_instagram: "Automatically share your posts on Instagram",
  // Add more as needed
};

function UpgradePrompt({ ability }: UpgradePromptProps) {
  const message = abilityMessages[ability] || "This feature requires an upgrade";

  return (
    <div className="upgrade-prompt">
      <LockIcon />
      <p>{message}</p>
      <Link to="/settings/subscription">Upgrade Now</Link>
    </div>
  );
}
```

### API Error Handler

```typescript
async function apiRequest(url: string, options?: RequestInit) {
  const response = await fetch(url, options);

  if (response.status === 403) {
    const data = await response.json();

    if (data.error === 'upgrade_required') {
      // Show upgrade modal or redirect
      showUpgradeModal({
        ability: data.required_ability,
        suggestedPlan: data.upgrade_plan
      });
      return null;
    }
  }

  return response.json();
}
```

---

## Plans Reference

| Plan Key | Role | Monthly | Annual | Description |
|----------|------|---------|--------|-------------|
| `fan_free` | fan | $0 | $0 | Free fan account |
| `band_free` | band | $0 | $0 | Free band account |
| `band_starter` | band | $15 | $156/yr | Band with analytics, storefront, newsletter |
| `band_pro` | band | $40 | $408/yr | Full band features |
| `blogger` | blogger | $9 | $96/yr | Basic blogger account |
| `blogger_pro` | blogger | $18 | $180/yr | Full blogger features |

### Plan-Ability Matrix

Use `GET /admin/plans/compare` to see the full matrix of which abilities each plan includes.

---

## Caching Considerations

The user's `abilities` array is computed from their plan at request time. When displaying the abilities:

1. **Store in auth context**: Keep the abilities array in your auth/user context
2. **Refresh on plan change**: Clear and re-fetch user data when the user upgrades/downgrades
3. **Don't cache indefinitely**: The abilities could change if an admin modifies plan-ability mappings

```typescript
// Example: Auth context with abilities
const AuthContext = createContext<{
  user: User | null;
  abilities: string[];
  can: (ability: string) => boolean;
  refreshUser: () => Promise<void>;
}>({
  user: null,
  abilities: [],
  can: () => false,
  refreshUser: async () => {},
});

function AuthProvider({ children }) {
  const [user, setUser] = useState<User | null>(null);

  const abilities = user?.abilities ?? [];

  const can = useCallback((ability: string) => {
    return abilities.includes(ability);
  }, [abilities]);

  const refreshUser = useCallback(async () => {
    const response = await fetch('/profile');
    const data = await response.json();
    setUser(data);
  }, []);

  return (
    <AuthContext.Provider value={{ user, abilities, can, refreshUser }}>
      {children}
    </AuthContext.Provider>
  );
}
```

---

## Testing Checklist

- [ ] All `account_type` references updated to `role`
- [ ] `music_blogger` values changed to `blogger`
- [ ] User type definitions updated with `role`, `plan`, `abilities`
- [ ] Navigation uses `role` for switching between views
- [ ] Feature gates use `abilities` instead of role checks
- [ ] Upgrade prompts show when abilities are missing
- [ ] Onboarding flow works with new response format
- [ ] API error handler catches `upgrade_required` errors

---

## Questions?

If you have questions about this migration, check:
- `docs/RBAC_SYSTEM.md` - Full system architecture
- `API_DOCUMENTATION.md` - Complete API reference
