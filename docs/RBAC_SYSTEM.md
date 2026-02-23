# GoodSongs: Roles, Plans & Abilities System — Product Requirements Document

## Overview

GoodSongs is introducing a third user type (Music Blogger) alongside existing Fan and Band accounts, with paid subscription tiers. The current architecture — storing account type on the backend and determining feature access on the frontend — will not scale to support multiple roles with multiple subscription levels and overlapping feature sets.

This document defines the architecture and requirements for a **roles, plans, and abilities** system that centralizes permission logic on the backend, making feature gating maintainable, enforceable, and easy to change without code deploys.

---

## Problem Statement

Today, the frontend determines what to show users based on a single `account_type` field. With the addition of Music Blogger accounts and paid subscription tiers, this approach creates several problems:

- Feature access logic becomes scattered across frontend components as brittle conditionals
- No backend enforcement — the API trusts the frontend to hide features correctly
- Moving a feature between tiers requires frontend code changes and redeployment
- Cross-role features (e.g., mailing lists available to both Blogger Pro and Band Pro) require special-case logic
- No clean path for upgrade prompts or ability-aware UI gating

---

## Goals

1. Centralize all feature-access logic on the backend
2. Make feature gating changes possible via database updates, not code deploys
3. Enforce permissions at the API level, not just the UI level
4. Support clean upgrade/downgrade flows with contextual prompts
5. Enable an admin interface for managing plan-ability mappings
6. Maintain backward compatibility with existing Fan and Band accounts

---

## Core Concepts

### Roles

A role is **what the user is**. It determines the fundamental UI experience, navigation structure, and onboarding flow. Roles rarely change and represent the user's identity on the platform.

| Role      | Description                                                  |
| --------- | ------------------------------------------------------------ |
| `fan`     | Discovers and recommends music. Free account.                |
| `band`    | Artist/band with business tools. Free + paid tiers.          |
| `blogger` | Music blogger with publishing and audience tools. Paid only. |

**Rules:**

- Every user has exactly one role
- Role changes are rare and may require data migration (e.g., a Fan upgrading to Blogger)
- Role determines which navigation, dashboard, and onboarding the user sees

### Plans

A plan is **what the user pays for**. Plans are tied to subscription state and determine the bundle of abilities a user has access to. Plans can change when a user upgrades, downgrades, or cancels.

| Plan           | Role    | Price  | Billing       |
| -------------- | ------- | ------ | ------------- |
| `fan_free`     | fan     | $0     | —             |
| `band_free`    | band    | $0     | —             |
| `band_starter` | band    | $15/mo | $13/mo annual |
| `band_pro`     | band    | $40/mo | $34/mo annual |
| `blogger`      | blogger | $9/mo  | $8/mo annual  |
| `blogger_pro`  | blogger | $18/mo | $15/mo annual |

**Rules:**

- Every user has exactly one active plan
- Plans belong to a specific role (a Fan cannot be on a Blogger plan)
- Plan changes trigger ability recalculation
- Downgrading does not delete data, but restricts access to gated features

### Abilities

An ability is **what the user can do**. Abilities are atomic permissions that the API checks before processing requests and that the frontend uses to show/hide UI elements. Abilities are never assigned directly to users — they are granted through plans.

**Rules:**

- Abilities are simple string keys (e.g., `create_blog_post`)
- The API resolves a user's abilities from their plan at request time
- Both the API and frontend check abilities, but the API is the source of truth
- An ability can belong to multiple plans (enabling cross-role feature sharing)

---

## Ability Definitions & Plan Mapping

### Fan Abilities

| Ability Key             | Description                          | fan_free |
| ----------------------- | ------------------------------------ | -------- |
| `create_recommendation` | Recommend songs to followers         | ✅       |
| `follow_users`          | Follow fans, bands, and bloggers     | ✅       |
| `create_comments`       | Comment on posts and recommendations | ✅       |
| `scrobble_lastfm`       | Last.fm scrobbling integration       | ✅       |

### Band Abilities

| Ability Key             | Description                  | band_free | band_starter | band_pro |
| ----------------------- | ---------------------------- | --------- | ------------ | -------- |
| `create_recommendation` | Recommend songs              | ✅        | ✅           | ✅       |
| `follow_users`          | Follow other users           | ✅        | ✅           | ✅       |
| `create_comments`       | Comment on content           | ✅        | ✅           | ✅       |
| `manage_band_profile`   | Edit band profile and bio    | ✅        | ✅           | ✅       |
| `upload_music`          | Upload tracks                | ✅        | ✅           | ✅       |
| `view_analytics`        | View page/profile analytics  | ❌        | ✅           | ✅       |
| `manage_storefront`     | Sell merch and music         | ❌        | ✅           | ✅       |
| `send_newsletter`       | Mailing list management      | ❌        | ✅           | ✅       |
| `manage_events`         | Create and manage events     | ❌        | ✅           | ✅       |
| `custom_design`         | Customize profile appearance | ❌        | ✅           | ✅       |

> **Note:** Band Starter vs Pro ability differentiation may need further refinement. The mapping above assumes Starter unlocks all paid features, with Pro offering higher limits, priority support, or additional advanced features to justify the $40/mo price point. Define the specific Pro-only abilities based on competitive analysis with Bandzoogle.

### Blogger Abilities

| Ability Key             | Description                                  | blogger | blogger_pro |
| ----------------------- | -------------------------------------------- | ------- | ----------- |
| `create_blog_post`      | Write and publish blog posts                 | ✅      | ✅          |
| `attach_images`         | Add images to blog posts                     | ✅      | ✅          |
| `attach_songs`          | Embed songs with music player                | ✅      | ✅          |
| `draft_posts`           | Save posts as drafts                         | ✅      | ✅          |
| `create_comments`       | Comment on content                           | ✅      | ✅          |
| `follow_users`          | Follow other users                           | ✅      | ✅          |
| `create_recommendation` | Recommend songs                              | ✅      | ✅          |
| `custom_design`         | Customize blog appearance                    | ✅      | ✅          |
| `custom_pages`          | Create About, Contact, etc.                  | ✅      | ✅          |
| `seo_controls`          | Meta descriptions, OG images, canonical URLs | ✅      | ✅          |
| `view_analytics`        | Page and post analytics                      | ✅      | ✅          |
| `manage_tags`           | Tag, genre, and category management          | ✅      | ✅          |
| `rss_feed`              | Public RSS feed for posts                    | ✅      | ✅          |
| `schedule_post`         | Schedule posts for future publication        | ❌      | ✅          |
| `manage_storefront`     | Sell merch                                   | ❌      | ✅          |
| `accept_donations`      | Accept reader donations                      | ❌      | ✅          |
| `manage_subscriptions`  | Paid reader subscriptions                    | ❌      | ✅          |
| `send_newsletter`       | Mailing list management                      | ❌      | ✅          |
| `manage_events`         | Create and promote events                    | ❌      | ✅          |
| `share_playlists`       | Share playlists across platforms             | ❌      | ✅          |
| `auto_post_instagram`   | Auto-post to Instagram                       | ❌      | ✅          |
| `auto_post_threads`     | Auto-post to Threads                         | ❌      | ✅          |
| `instagram_display`     | Display Instagram feed on profile            | ❌      | ✅          |

---

## Data Model

### Database Schema

#### `plans` table

| Column                | Type     | Description                                                                |
| --------------------- | -------- | -------------------------------------------------------------------------- |
| `id`                  | bigint   | Primary key                                                                |
| `key`                 | string   | Unique identifier (e.g., `blogger_pro`)                                    |
| `name`                | string   | Display name (e.g., "Blogger Pro")                                         |
| `role`                | string   | Associated role (`fan`, `band`, `blogger`)                                 |
| `price_cents_monthly` | integer  | Monthly price in cents (0 for free)                                        |
| `price_cents_annual`  | integer  | Annual price in cents, calculated as 16% discount off monthly (0 for free) |
| `active`              | boolean  | Whether plan is available for new signups                                  |
| `created_at`          | datetime |                                                                            |
| `updated_at`          | datetime |                                                                            |

#### `abilities` table

| Column        | Type     | Description                                                       |
| ------------- | -------- | ----------------------------------------------------------------- |
| `id`          | bigint   | Primary key                                                       |
| `key`         | string   | Unique identifier (e.g., `schedule_post`)                         |
| `name`        | string   | Human-readable name (e.g., "Schedule Posts")                      |
| `description` | text     | What this ability enables                                         |
| `category`    | string   | Grouping for admin UI (e.g., `content`, `monetization`, `social`) |
| `created_at`  | datetime |                                                                   |
| `updated_at`  | datetime |                                                                   |

#### `plan_abilities` join table

| Column       | Type     | Description              |
| ------------ | -------- | ------------------------ |
| `id`         | bigint   | Primary key              |
| `plan_id`    | bigint   | Foreign key to plans     |
| `ability_id` | bigint   | Foreign key to abilities |
| `created_at` | datetime |                          |

#### Changes to `users` table

| Column    | Type   | Description                                                                         |
| --------- | ------ | ----------------------------------------------------------------------------------- |
| `role`    | string | User's role (`fan`, `band`, `blogger`) — **replaces or supplements `account_type`** |
| `plan_id` | bigint | Foreign key to current plan                                                         |

### Relationships

```
User belongs_to Plan
Plan has_many PlanAbilities
Plan has_many Abilities (through PlanAbilities)
Ability has_many PlanAbilities
Ability has_many Plans (through PlanAbilities)
```

### Key Model Methods

```ruby
# User model
class User < ApplicationRecord
  belongs_to :plan

  def abilities
    plan.abilities.pluck(:key)
  end

  def can?(ability_key)
    plan.abilities.exists?(key: ability_key)
  end

  def cannot?(ability_key)
    !can?(ability_key)
  end

  def upgrade_plan_for(ability_key)
    Plan.where(role: role)
        .joins(:abilities)
        .where(abilities: { key: ability_key })
        .where.not(id: plan_id)
        .order(:price_cents_monthly)
        .first
  end
end
```

---

## API Contract

### User Serializer

The user endpoint should return the resolved abilities array so the frontend never computes permissions locally.

```json
{
  "user": {
    "id": 123,
    "username": "indiemelody",
    "role": "blogger",
    "plan": {
      "key": "blogger_pro",
      "name": "Blogger Pro"
    },
    "abilities": [
      "create_blog_post",
      "attach_images",
      "attach_songs",
      "draft_posts",
      "schedule_post",
      "create_comments",
      "follow_users",
      "create_recommendation",
      "custom_design",
      "custom_pages",
      "seo_controls",
      "view_analytics",
      "manage_tags",
      "rss_feed",
      "manage_storefront",
      "accept_donations",
      "manage_subscriptions",
      "send_newsletter",
      "manage_events",
      "share_playlists",
      "auto_post_instagram",
      "auto_post_threads",
      "instagram_display"
    ]
  }
}
```

### API Enforcement

Every API endpoint that corresponds to a gated feature must check the user's ability before processing:

```ruby
# app/controllers/concerns/ability_check.rb
module AbilityCheck
  extend ActiveSupport::Concern

  def require_ability!(ability_key)
    unless current_user.can?(ability_key)
      render json: {
        error: "upgrade_required",
        message: "This feature requires an upgrade.",
        required_ability: ability_key,
        upgrade_plan: current_user.upgrade_plan_for(ability_key)&.key
      }, status: :forbidden
    end
  end
end

# Usage in controllers
class ScheduledPostsController < ApplicationController
  before_action -> { require_ability!("schedule_post") }

  def create
    # Only reached if user has the schedule_post ability
  end
end
```

### Upgrade Prompt Response

When a user attempts a gated action, the 403 response includes enough info for the frontend to show a contextual upgrade prompt:

```json
{
  "error": "upgrade_required",
  "message": "This feature requires an upgrade.",
  "required_ability": "schedule_post",
  "upgrade_plan": "blogger_pro"
}
```

---

## Frontend Implementation

### Ability Checking

The frontend should store the user's abilities from the API response and provide a simple helper:

```typescript
// hooks/useAbility.ts
export function useAbility(abilityKey: string): boolean {
  const { user } = useAuth();
  return user?.abilities?.includes(abilityKey) ?? false;
}

// Usage in components
function PostEditor() {
  const canSchedule = useAbility("schedule_post");

  return (
    <div>
      <Editor />
      {canSchedule ? (
        <ScheduleButton />
      ) : (
        <UpgradePrompt feature="schedule_post" />
      )}
    </div>
  );
}
```

### Upgrade Prompt Component

A reusable component that shows when a user encounters a gated feature:

```typescript
function UpgradePrompt({ feature }: { feature: string }) {
  // Map feature keys to user-friendly messaging
  const messages: Record<string, string> = {
    schedule_post: "Schedule posts for the perfect publish time",
    manage_storefront: "Sell merch directly to your readers",
    send_newsletter: "Build and manage your mailing list",
    // ... etc
  };

  return (
    <div className="upgrade-prompt">
      <p>{messages[feature]}</p>
      <a href="/upgrade">Upgrade to Blogger Pro</a>
    </div>
  );
}
```

### Role-Based Navigation

Navigation structure should still be role-driven (not ability-driven) since the overall UI experience differs by role:

```typescript
function AppNavigation() {
  const { user } = useAuth();

  switch (user.role) {
    case "fan":
      return <FanNavigation />;
    case "band":
      return <BandNavigation />;
    case "blogger":
      return <BloggerNavigation />;
  }
}
```

Within each navigation, individual items can be gated by ability.

---

## Admin Interface Requirements

### Purpose

Provide an internal tool for managing plans, abilities, and their mappings without code changes or deployments. This is critical for rapid iteration on pricing and feature gating during the Blogger launch.

### Access

- Available at `/admin/plans` (or similar)
- Restricted to admin users only
- No public-facing components

### Views & Functionality

#### 1. Plans List (`/admin/plans`)

Displays all plans with summary information.

| Column          | Content                      |
| --------------- | ---------------------------- |
| Name            | Plan display name            |
| Key             | Unique identifier            |
| Role            | Associated role              |
| Monthly Price   | Formatted price              |
| Annual Price    | Formatted price              |
| Abilities Count | Number of granted abilities  |
| Active          | Whether available for signup |
| Actions         | Edit, Deactivate             |

**Actions:**

- Create new plan
- Edit existing plan
- Activate/deactivate plan (soft disable — does not affect current subscribers)

#### 2. Abilities List (`/admin/abilities`)

Displays all defined abilities.

| Column   | Content                                        |
| -------- | ---------------------------------------------- |
| Name     | Human-readable name                            |
| Key      | Unique identifier                              |
| Category | Grouping (content, monetization, social, etc.) |
| Plans    | Which plans include this ability               |
| Actions  | Edit                                           |

**Actions:**

- Create new ability
- Edit ability metadata
- View which plans grant this ability

#### 3. Plan Detail / Ability Mapping (`/admin/plans/:id`)

The most important view. Shows a single plan and allows toggling abilities on/off.

**Plan Info Section:**

- Edit name, price, active status

**Abilities Section:**

- Grouped by category (Content, Monetization, Social, Analytics, etc.)
- Checkbox for each ability — checked means the plan grants it
- Save button applies changes immediately
- Changes affect all users on this plan in real time

**Visual mockup concept:**

```
Plan: Blogger Pro ($18/mo)
Role: blogger | Status: Active

CONTENT
  ☑ Create Blog Posts
  ☑ Attach Images
  ☑ Attach Songs
  ☑ Draft Posts
  ☑ Schedule Posts
  ☑ Custom Pages
  ☑ Manage Tags
  ☑ RSS Feed
  ☑ SEO Controls

MONETIZATION
  ☑ Manage Storefront
  ☑ Accept Donations
  ☑ Manage Subscriptions

AUDIENCE
  ☑ Send Newsletter
  ☑ Follow Users
  ☑ Create Comments
  ☑ Create Recommendation

SOCIAL
  ☑ Auto Post Instagram
  ☑ Auto Post Threads
  ☑ Instagram Display
  ☑ Share Playlists

ANALYTICS
  ☑ View Analytics

[Save Changes]
```

#### 4. Comparison View (`/admin/plans/compare`)

Side-by-side matrix of all plans and abilities for quick auditing.

```
                    | fan_free | band_free | band_starter | band_pro | blogger | blogger_pro
--------------------|----------|-----------|--------------|----------|---------|------------
create_blog_post    |          |           |              |          |    ✅   |     ✅
schedule_post       |          |           |              |          |         |     ✅
manage_storefront   |          |           |      ✅      |    ✅    |         |     ✅
send_newsletter     |          |           |      ✅      |    ✅    |         |     ✅
create_recommendation|   ✅    |     ✅    |      ✅      |    ✅    |    ✅   |     ✅
...
```

This view is read-only and useful for verifying that feature gating is correct across all plans.

#### 5. Audit Log (`/admin/plans/audit`)

Track all changes to plan-ability mappings for accountability.

| Column    | Content                         |
| --------- | ------------------------------- |
| Timestamp | When the change occurred        |
| Admin     | Who made the change             |
| Action    | Added/removed ability from plan |
| Plan      | Affected plan                   |
| Ability   | Affected ability                |

---

## Migration Plan

### Phase 1: Database Setup

1. Create `plans`, `abilities`, and `plan_abilities` tables
2. Seed all plans and abilities with the mappings defined in this document
3. Add `role` and `plan_id` columns to `users` table

### Phase 2: Data Migration

1. Map existing `account_type` values to roles and plans:
   - `account_type: "fan"` → `role: "fan"`, `plan: fan_free`
   - `account_type: "band"` → `role: "band"`, `plan: band_free`
2. Backfill all existing users
3. Validate that no users are left without a role and plan
4. Implement Fan → Blogger upgrade path:
   - User's role changes from `fan` to `blogger`
   - Existing recommendations and followers carry over
   - Fan abilities are retained (included in all Blogger plans)
   - Trigger subscription flow for selected Blogger plan

### Phase 3: Backend Enforcement

1. Add `AbilityCheck` concern to `ApplicationController`
2. Add `can?` and ability methods to `User` model
3. Update user serializer to include `role`, `plan`, and `abilities`
4. Add `before_action` ability checks to existing gated controllers
5. Write tests for ability enforcement on all protected endpoints

### Phase 4: Frontend Migration

1. Update auth context to store and expose abilities from API
2. Create `useAbility` hook
3. Replace existing `account_type` conditionals with ability checks
4. Add `UpgradePrompt` component for gated features
5. Update navigation to use role-based switching

### Phase 5: Admin Interface

1. Build Plans CRUD
2. Build Abilities CRUD
3. Build plan-ability mapping UI with checkbox toggles
4. Build comparison view
5. Build audit log

### Phase 6: Subscription Integration

1. Integrate payment provider (Stripe recommended) for Blogger tiers
2. Connect plan changes to subscription lifecycle events (upgrade, downgrade, cancel, renewal)
3. Handle grace periods for downgrades (user keeps Pro abilities until current billing period ends)
4. Add billing management UI for Blogger accounts

---

## Open Questions

1. **Band Starter vs Pro differentiation** — Both tiers are priced ($15/mo and $40/mo). Ability mapping to be defined separately.
2. **Role switching** — ✅ Fans can upgrade to Blogger as a natural progression path. Define the migration: existing recommendations and followers should carry over, and the user gains Blogger abilities on top of their existing Fan capabilities.
3. **Grandfathering** — TBD. Decide before launch whether existing subscribers keep original abilities or update automatically when plan mappings change.
4. **Trial period** — Deferred. Will be introduced alongside the billing system integration.
5. **Annual billing** — All annual plans offer a 16% discount off the monthly price. No bonus abilities — annual is a pricing incentive only.

| Plan           | Monthly | Annual (~16% savings) |
| -------------- | ------- | --------------------- |
| `blogger`      | $9/mo   | $8/mo ($96/yr)        |
| `blogger_pro`  | $18/mo  | $15/mo ($180/yr)      |
| `band_starter` | $15/mo  | $13/mo ($156/yr)      |
| `band_pro`     | $40/mo  | $34/mo ($408/yr)      |

---

## Success Criteria

- All feature access is enforced at the API level, not just the frontend
- A non-technical admin can change which features belong to which plan without a code deploy
- Adding a new ability to the system requires only a database seed and a controller `before_action`
- Upgrade prompts appear contextually when users encounter gated features
- Existing Fan and Band users experience zero disruption during migration
