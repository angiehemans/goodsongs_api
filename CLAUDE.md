# CLAUDE.md — GoodSongs API

## Rules

- **Always update `API_DOCUMENTATION.md`** when making changes to API endpoints, request/response formats, authentication, or any user-facing behavior. This includes adding, modifying, or removing endpoints, changing response shapes, adding fields, or updating error responses. Check the existing docs first to understand the current state before making edits.

## Project Overview

- Ruby on Rails API backend for GoodSongs
- No frontend — this is a JSON API only
- Authentication is token-based (see `ApplicationController`)

## Key Directories

- `app/services/` — business logic (e.g., `QueryService` for feed/query building)
- `app/serializers/` — response formatting (not ActiveModel serializers, plain Ruby classes with class methods)
- `app/controllers/api/v1/` — versioned API endpoints (dashboards, profiles)
- `app/controllers/` — top-level resource controllers

## Common Patterns

- Serializers use class methods like `.full()`, `.summary()`, `.for_feed()` — not instance methods
- `current_user` is the authenticated user; `authenticated_user` is available in public endpoints (may be nil)
- `ImageUrlHelper` is extended into serializers for `profile_image_url` and `attachment_url`
- Feeds use `{ type: "review"|"post"|"event", data: {...} }` item format
