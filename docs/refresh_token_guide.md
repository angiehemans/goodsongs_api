# Refresh Token Implementation Guide

This guide covers how to correctly implement the access/refresh token flow in the Next.js web app and React Native mobile app.

## How the Token System Works

The API uses a **two-token strategy**:

| Token | Lifetime | Storage | Purpose |
|-------|----------|---------|---------|
| **Access token** (`auth_token`) | 1 hour | Memory / short-lived storage | Sent as `Authorization: Bearer <token>` on every API request |
| **Refresh token** (`refresh_token`) | 90 days | Secure persistent storage | Exchanged for a new access + refresh token pair when the access token expires |

**Token rotation**: Every time you call `/auth/refresh`, the old refresh token is **revoked** and a new one is returned. You must store and use the new refresh token for subsequent refreshes. Using a revoked token returns `401`.

---

## API Endpoints

### Login — `POST /login`

```json
// Request
{
  "email": "user@example.com",
  "password": "secret",
  "device_name": "My iPhone"  // optional, shown in session management
}

// Response 200
{
  "auth_token": "eyJhbGciOi...",
  "refresh_token": "a1b2c3d4e5...",
  "expires_in": 3600,
  "user": { "id": 42, "username": "jane", "role": "band", ... }
}
```

### Refresh — `POST /auth/refresh`

```json
// Request
{ "refresh_token": "a1b2c3d4e5..." }

// Response 200 — new token pair
{
  "auth_token": "eyJhbGciOi...",
  "refresh_token": "f6g7h8i9j0...",
  "expires_in": 3600
}

// Response 401 — token is revoked, expired, or invalid
{
  "error": "Invalid or expired refresh token",
  "code": "invalid_refresh_token"
}
```

### Logout (current device) — `POST /auth/logout`

```json
// Request
{ "refresh_token": "a1b2c3d4e5..." }

// Response 200
{ "message": "Logged out successfully" }
```

### Logout (all devices) — `POST /auth/logout-all`

Requires `Authorization: Bearer <access_token>` header.

```json
// Response 200
{ "message": "Logged out from all devices successfully" }
```

---

## Error Codes to Handle

| HTTP Status | `code` field | Meaning | Action |
|-------------|-------------|---------|--------|
| 401 | `token_expired` | Access token has expired | Refresh the token silently, then retry the original request |
| 422 | — | Token is missing or malformed | Redirect to login |
| 401 | `invalid_refresh_token` | Refresh token is revoked/expired/invalid | Redirect to login |
| 401 | `account_disabled` | User account is disabled | Show disabled message, redirect to login |

---

## Implementation Steps

### 1. Store Tokens After Login

**Next.js (Web):**
```typescript
// After POST /login succeeds
const { auth_token, refresh_token, expires_in } = response.data;

// Store access token in memory (NOT localStorage for security)
setAccessToken(auth_token);

// Store refresh token in an httpOnly cookie or secure storage
// If using cookies, set from the client:
document.cookie = `refresh_token=${refresh_token}; path=/; max-age=${90 * 86400}; secure; samesite=strict`;

// Or store in localStorage if httpOnly cookies aren't feasible
localStorage.setItem('refresh_token', refresh_token);

// Track when the token expires
const expiresAt = Date.now() + expires_in * 1000;
setTokenExpiresAt(expiresAt);
```

**React Native:**
```typescript
import * as SecureStore from 'expo-secure-store';

// After POST /login succeeds
const { auth_token, refresh_token, expires_in } = response.data;

// Store access token in memory
setAccessToken(auth_token);

// Store refresh token in secure storage (Keychain/Keystore)
await SecureStore.setItemAsync('refresh_token', refresh_token);

// Track expiration
const expiresAt = Date.now() + expires_in * 1000;
setTokenExpiresAt(expiresAt);
```

### 2. Attach Access Token to Every Request

Set up an Axios/fetch interceptor that adds the `Authorization` header:

```typescript
api.interceptors.request.use((config) => {
  const token = getAccessToken();
  if (token) {
    config.headers.Authorization = `Bearer ${token}`;
  }
  return config;
});
```

### 3. Intercept 401 Responses and Refresh

This is the critical part. You need a **response interceptor** that:

1. Catches `401` responses with `code: "token_expired"`
2. Calls `/auth/refresh` with the stored refresh token
3. Stores the **new** token pair (both access AND refresh token)
4. Retries the original failed request with the new access token
5. Queues concurrent requests while a refresh is in-flight (prevents multiple simultaneous refresh calls)

```typescript
let isRefreshing = false;
let failedQueue: Array<{
  resolve: (token: string) => void;
  reject: (error: any) => void;
}> = [];

function processQueue(error: any, token: string | null) {
  failedQueue.forEach(({ resolve, reject }) => {
    if (error) {
      reject(error);
    } else {
      resolve(token!);
    }
  });
  failedQueue = [];
}

api.interceptors.response.use(
  (response) => response,
  async (error) => {
    const originalRequest = error.config;

    // Only handle token_expired, not other 401s
    if (
      error.response?.status === 401 &&
      error.response?.data?.code === 'token_expired' &&
      !originalRequest._retry
    ) {
      // If already refreshing, queue this request
      if (isRefreshing) {
        return new Promise((resolve, reject) => {
          failedQueue.push({ resolve, reject });
        }).then((token) => {
          originalRequest.headers.Authorization = `Bearer ${token}`;
          return api(originalRequest);
        });
      }

      originalRequest._retry = true;
      isRefreshing = true;

      try {
        const refreshToken = await getRefreshToken(); // from storage

        if (!refreshToken) {
          throw new Error('No refresh token');
        }

        const { data } = await api.post('/auth/refresh', {
          refresh_token: refreshToken,
        });

        // CRITICAL: Store BOTH the new access token AND new refresh token
        setAccessToken(data.auth_token);
        await setRefreshToken(data.refresh_token); // <-- DON'T FORGET THIS

        processQueue(null, data.auth_token);

        // Retry original request
        originalRequest.headers.Authorization = `Bearer ${data.auth_token}`;
        return api(originalRequest);
      } catch (refreshError) {
        processQueue(refreshError, null);

        // Refresh failed — clear tokens and redirect to login
        clearTokens();
        redirectToLogin();

        return Promise.reject(refreshError);
      } finally {
        isRefreshing = false;
      }
    }

    // For 401s that are NOT token_expired (e.g., invalid_refresh_token,
    // account_disabled), redirect to login immediately
    if (error.response?.status === 401) {
      const code = error.response?.data?.code;
      if (code === 'invalid_refresh_token' || code === 'account_disabled') {
        clearTokens();
        redirectToLogin();
      }
    }

    return Promise.reject(error);
  }
);
```

### 4. Proactive Refresh (Optional but Recommended)

Instead of waiting for a 401, refresh the token before it expires:

```typescript
function scheduleTokenRefresh(expiresIn: number) {
  // Refresh 5 minutes before expiry
  const refreshIn = (expiresIn - 300) * 1000;

  if (refreshIn <= 0) {
    // Token is already about to expire, refresh now
    refreshAccessToken();
    return;
  }

  setTimeout(() => {
    refreshAccessToken();
  }, refreshIn);
}

async function refreshAccessToken() {
  try {
    const refreshToken = await getRefreshToken();
    if (!refreshToken) return;

    const { data } = await api.post('/auth/refresh', {
      refresh_token: refreshToken,
    });

    setAccessToken(data.auth_token);
    await setRefreshToken(data.refresh_token);

    // Schedule next refresh
    scheduleTokenRefresh(data.expires_in);
  } catch {
    // Silent failure — the 401 interceptor will handle it on next request
  }
}
```

Call `scheduleTokenRefresh(expires_in)` after login and after every successful refresh.

### 5. Handle Logout

```typescript
async function logout() {
  try {
    const refreshToken = await getRefreshToken();
    await api.post('/auth/logout', { refresh_token: refreshToken });
  } catch {
    // Ignore errors — we're logging out anyway
  } finally {
    clearTokens();
    redirectToLogin();
  }
}
```

### 6. Handle App Resume (React Native)

When the app comes back to the foreground, check if the access token is still valid:

```typescript
import { AppState } from 'react-native';

AppState.addEventListener('change', (state) => {
  if (state === 'active') {
    const expiresAt = getTokenExpiresAt();
    if (expiresAt && Date.now() >= expiresAt) {
      refreshAccessToken();
    }
  }
});
```

---

## Common Mistakes

### 1. Not storing the new refresh token after refresh
The API uses **token rotation**. After `/auth/refresh`, the old refresh token is revoked. If you don't store the new `refresh_token` from the response, the next refresh attempt will fail with `invalid_refresh_token` and the user gets logged out.

### 2. Multiple simultaneous refresh calls
If 3 requests fail at the same time with `token_expired`, you must NOT fire 3 `/auth/refresh` calls. The first one will succeed and revoke the token — the other 2 will fail because they're using the now-revoked refresh token. Use the queue pattern shown above.

### 3. Refreshing on the wrong 401
Only refresh when `code === "token_expired"`. Other 401 errors (`invalid_refresh_token`, `account_disabled`, generic auth failures) should redirect to login, not trigger a refresh loop.

### 4. Storing access tokens in localStorage
Access tokens should live in memory (a variable, React context/state, or Zustand/Redux store). They're short-lived by design. Putting them in localStorage exposes them to XSS. Refresh tokens in localStorage are acceptable as a tradeoff if httpOnly cookies aren't feasible.

### 5. Not handling refresh failure gracefully
If `/auth/refresh` returns a non-200, clear all tokens and redirect to login. Don't retry the refresh — it means the session is dead.

---

## Flow Diagram

```
[App Start]
  │
  ├─ Has refresh token in storage?
  │   ├─ No  → Show login screen
  │   └─ Yes → Call POST /auth/refresh
  │             ├─ 200 → Store new tokens, go to app
  │             └─ 401 → Clear tokens, show login screen
  │
[Making API Request]
  │
  ├─ Attach access token as Authorization header
  ├─ Response 200 → Success
  ├─ Response 401 + code: "token_expired"
  │   ├─ Refresh already in progress? → Queue request
  │   └─ Call POST /auth/refresh
  │       ├─ 200 → Store new tokens, retry original request
  │       └─ 401 → Clear tokens, redirect to login
  └─ Response 401 + other code → Clear tokens, redirect to login
```

---

## Quick Checklist

- [ ] Access token stored in memory only (not localStorage)
- [ ] Refresh token stored in secure persistent storage
- [ ] `Authorization: Bearer <token>` header on every authenticated request
- [ ] Response interceptor catches `401` + `code: "token_expired"` specifically
- [ ] Interceptor calls `POST /auth/refresh` with the stored refresh token
- [ ] **Both** `auth_token` and `refresh_token` from the refresh response are stored
- [ ] Concurrent 401s are queued — only one refresh call fires at a time
- [ ] Failed refresh clears all tokens and redirects to login
- [ ] Logout sends `POST /auth/logout` with the refresh token before clearing local state
- [ ] React Native: check token on app resume from background
