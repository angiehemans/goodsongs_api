# Push Notifications Setup Guide

This guide covers setting up push notifications for the GoodSongs mobile app using Firebase Cloud Messaging (FCM) V1 API and Ruby on Rails.

> **Note:** This guide uses the FCM V1 API with service account authentication. The legacy Cloud Messaging API (Server Key) was fully deprecated in June 2024.

## Overview

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│  Rails API  │────▶│   Firebase  │────▶│  Mobile App │
│  (sender)   │     │     FCM     │     │  (receiver) │
└─────────────┘     └─────────────┘     └─────────────┘
```

1. Mobile app registers with FCM and receives a device token
2. App sends the token to Rails backend (stored in Postgres)
3. When events occur (new follower, like, comment), Rails sends notification to FCM
4. FCM delivers the push notification to the device

---

## Part 1: Firebase Setup

### 1.1 Create Firebase Project

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Click "Create a project"
3. Name it "GoodSongs" (or similar)
4. Disable Google Analytics (optional, not needed for push notifications)
5. Click "Create project"

### 1.2 Add Android App to Firebase

1. In Firebase Console, click "Add app" → Android icon
2. Enter package name: `com.goodsongs.mobile` (check `android/app/build.gradle` for exact name)
3. Enter app nickname: "GoodSongs Android"
4. Click "Register app"
5. Download `google-services.json`
6. Place it in `apps/mobile/android/app/google-services.json`

### 1.3 Create Service Account for Rails (FCM V1 API)

The legacy Cloud Messaging API is deprecated. Use the FCM V1 API with a service account:

1. In Firebase Console → Project Settings → **Service accounts** tab
2. Click **"Generate new private key"**
3. Click **"Generate key"** to download the JSON file
4. Rename it to `firebase-service-account.json`
5. Place it in your Rails app at `config/firebase-service-account.json`
6. **Important:** Add this file to `.gitignore` - never commit it to version control!

```bash
# Add to .gitignore
config/firebase-service-account.json
```

Also note your **Project ID** from the Project Settings → General tab (e.g., `goodsongs-12345`)

---

## Part 2: Android App Setup

### 2.1 Install Dependencies

```bash
cd apps/mobile
pnpm add @react-native-firebase/app @react-native-firebase/messaging
```

### 2.2 Configure Android

**android/build.gradle** - Add Google services plugin (using plugins DSL):

```gradle
plugins {
    // ... existing plugins
    id 'com.google.gms.google-services' version '4.4.4' apply false
}
```

**android/app/build.gradle** - Apply plugin at top and add Firebase BOM:

```gradle
apply plugin: "com.android.application"
apply plugin: "org.jetbrains.kotlin.android"
apply plugin: "com.facebook.react"
apply plugin: 'com.google.gms.google-services'

// ... rest of config ...

dependencies {
    // ... existing dependencies
    implementation platform('com.google.firebase:firebase-bom:34.9.0')
}
```

### 2.3 Add Firebase Messaging to App

Create `apps/mobile/src/utils/pushNotifications.ts`:

```typescript
import messaging from "@react-native-firebase/messaging";
import { Platform } from "react-native";
import { apiClient } from "./api";

export async function requestNotificationPermission(): Promise<boolean> {
  const authStatus = await messaging().requestPermission();
  const enabled =
    authStatus === messaging.AuthorizationStatus.AUTHORIZED ||
    authStatus === messaging.AuthorizationStatus.PROVISIONAL;

  return enabled;
}

export async function registerForPushNotifications(): Promise<string | null> {
  try {
    // Request permission
    const hasPermission = await requestNotificationPermission();
    if (!hasPermission) {
      console.log("Push notification permission denied");
      return null;
    }

    // Get FCM token
    const token = await messaging().getToken();
    console.log("FCM Token:", token);

    // Send token to backend
    await apiClient.registerDeviceToken(token, Platform.OS);

    return token;
  } catch (error) {
    console.error("Failed to register for push notifications:", error);
    return null;
  }
}

export function setupNotificationHandlers() {
  // Handle notification when app is in foreground
  messaging().onMessage(async (remoteMessage) => {
    console.log("Foreground notification:", remoteMessage);
    // You can show an in-app alert or update the notification badge
  });

  // Handle notification tap when app is in background
  messaging().onNotificationOpenedApp((remoteMessage) => {
    console.log("Notification opened app:", remoteMessage);
    // Navigate to relevant screen based on notification data
  });

  // Handle notification tap when app was closed
  messaging()
    .getInitialNotification()
    .then((remoteMessage) => {
      if (remoteMessage) {
        console.log("App opened from notification:", remoteMessage);
        // Navigate to relevant screen
      }
    });

  // Listen for token refresh
  messaging().onTokenRefresh(async (token) => {
    await apiClient.registerDeviceToken(token, Platform.OS);
  });
}
```

### 2.4 Add API Method for Device Token

Add to `apps/mobile/src/utils/api.ts`:

```typescript
async registerDeviceToken(token: string, platform: string): Promise<void> {
  return this.request('/device_tokens', {
    method: 'POST',
    body: JSON.stringify({
      device_token: {
        token,
        platform,
      },
    }),
  });
}

async unregisterDeviceToken(token: string): Promise<void> {
  return this.request('/device_tokens', {
    method: 'DELETE',
    body: JSON.stringify({ token }),
  });
}
```

### 2.5 Initialize in App

In `apps/mobile/src/navigation/AppNavigator.tsx`, add after authentication:

```typescript
import {
  registerForPushNotifications,
  setupNotificationHandlers,
} from "@/utils/pushNotifications";

// Inside AppNavigator component, after user is authenticated:
useEffect(() => {
  if (isAuthenticated) {
    registerForPushNotifications();
    setupNotificationHandlers();
  }
}, [isAuthenticated]);
```

---

## Part 3: Rails Backend Setup

### 3.1 Install FCM Gem

Add to `Gemfile`:

```ruby
gem 'fcm'
```

Run `bundle install`

### 3.2 Create Device Tokens Table

```bash
rails generate migration CreateDeviceTokens
```

Edit the migration:

```ruby
class CreateDeviceTokens < ActiveRecord::Migration[7.0]
  def change
    create_table :device_tokens do |t|
      t.references :user, null: false, foreign_key: true
      t.string :token, null: false
      t.string :platform, null: false  # 'ios' or 'android'
      t.datetime :last_used_at
      t.timestamps
    end

    add_index :device_tokens, :token, unique: true
    add_index :device_tokens, [:user_id, :platform]
  end
end
```

Run `rails db:migrate`

### 3.3 Create DeviceToken Model

`app/models/device_token.rb`:

```ruby
class DeviceToken < ApplicationRecord
  belongs_to :user

  validates :token, presence: true, uniqueness: true
  validates :platform, presence: true, inclusion: { in: %w[ios android] }

  scope :active, -> { where('last_used_at > ?', 30.days.ago) }
end
```

Add to `app/models/user.rb`:

```ruby
has_many :device_tokens, dependent: :destroy
```

### 3.4 Create Device Tokens Controller

`app/controllers/api/v1/device_tokens_controller.rb`:

```ruby
module Api
  module V1
    class DeviceTokensController < ApplicationController
      before_action :authenticate_user!

      def create
        token = current_user.device_tokens.find_or_initialize_by(
          token: device_token_params[:token]
        )
        token.platform = device_token_params[:platform]
        token.last_used_at = Time.current

        if token.save
          render json: { message: 'Device registered' }, status: :ok
        else
          render json: { errors: token.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def destroy
        token = current_user.device_tokens.find_by(token: params[:token])
        token&.destroy
        render json: { message: 'Device unregistered' }, status: :ok
      end

      private

      def device_token_params
        params.require(:device_token).permit(:token, :platform)
      end
    end
  end
end
```

Add route in `config/routes.rb`:

```ruby
namespace :api do
  namespace :v1 do
    resources :device_tokens, only: [:create, :destroy]
  end
end
```

### 3.5 Create Push Notification Service

`app/services/push_notification_service.rb`:

```ruby
class PushNotificationService
  def initialize
    # FCM V1 API uses service account authentication
    # FCM.new(json_key_path, project_name, http_options = {})
    @fcm = FCM.new(
      Rails.root.join('config', 'firebase-service-account.json').to_s,
      ENV['FIREBASE_PROJECT_ID'],
      {}
    )
  end

  def send_to_user(user, title:, body:, data: {})
    tokens = user.device_tokens.active.pluck(:token)
    return if tokens.empty?

    send_to_tokens(tokens, title: title, body: body, data: data)
  end

  def send_to_tokens(tokens, title:, body:, data: {})
    return if tokens.empty?

    # FCM V1 API sends to one token at a time
    responses = tokens.map do |token|
      send_to_token(token, title: title, body: body, data: data)
    end

    handle_responses(responses, tokens)
  end

  private

  def send_to_token(token, title:, body:, data: {})
    message = {
      token: token,
      notification: {
        title: title,
        body: body
      },
      data: data.transform_values(&:to_s),
      # Android-specific options
      android: {
        priority: 'high',
        notification: {
          sound: 'default',
          click_action: 'FLUTTER_NOTIFICATION_CLICK'
        }
      },
      # iOS-specific options (APNs)
      apns: {
        payload: {
          aps: {
            sound: 'default',
            badge: 1
          }
        }
      }
    }

    @fcm.send_v1(message)
  rescue StandardError => e
    Rails.logger.error("FCM send failed for token #{token[0..10]}...: #{e.message}")
    { error: e.message, token: token }
  end

  def handle_responses(responses, tokens)
    responses.each_with_index do |response, index|
      next unless response.is_a?(Hash)

      # Handle invalid/unregistered tokens
      if response[:status_code] == 404 ||
         response.dig(:body, 'error', 'code') == 404 ||
         response.dig(:body, 'error', 'status') == 'NOT_FOUND'
        DeviceToken.where(token: tokens[index]).destroy_all
        Rails.logger.info("Removed invalid FCM token: #{tokens[index][0..10]}...")
      end
    end

    responses
  end
end
```

### 3.6 Configure Environment Variables

Add to your environment (`.env`):

```bash
# Your Firebase project ID (found in Firebase Console → Project Settings → General)
FIREBASE_PROJECT_ID=goodsongs-12345
```

For production, you can also set the service account JSON as an environment variable instead of a file:

```bash
# Alternative: Set the entire JSON as an env var (useful for Heroku, Railway, etc.)
FIREBASE_SERVICE_ACCOUNT_JSON='{"type":"service_account","project_id":"...",...}'
```

If using the environment variable approach, update the service initialization:

```ruby
def initialize
  credentials = if ENV['FIREBASE_SERVICE_ACCOUNT_JSON'].present?
    # Parse JSON from environment variable
    StringIO.new(ENV['FIREBASE_SERVICE_ACCOUNT_JSON'])
  else
    # Use file path
    Rails.root.join('config', 'firebase-service-account.json').to_s
  end

  # FCM.new(json_key_path, project_name, http_options = {})
  @fcm = FCM.new(credentials, ENV['FIREBASE_PROJECT_ID'], {})
end
```

### 3.7 Send Notifications from Models/Jobs

Create a job for sending notifications:

`app/jobs/send_push_notification_job.rb`:

```ruby
class SendPushNotificationJob < ApplicationJob
  queue_as :default

  def perform(user_id, title:, body:, data: {})
    user = User.find_by(id: user_id)
    return unless user

    PushNotificationService.new.send_to_user(
      user,
      title: title,
      body: body,
      data: data
    )
  end
end
```

### 3.8 Trigger Notifications on Events

Update your notification creation logic to also send push notifications.

Example in a callback or service:

```ruby
# When creating a follow notification
def notify_new_follower(follower, followed_user)
  # Create in-app notification (existing logic)
  notification = followed_user.notifications.create!(
    notification_type: 'new_follower',
    actor: follower,
    message: "#{follower.username} started following you"
  )

  # Send push notification
  SendPushNotificationJob.perform_later(
    followed_user.id,
    title: 'New Follower',
    body: "#{follower.username} started following you",
    data: {
      type: 'new_follower',
      notification_id: notification.id.to_s,
      actor_username: follower.username
    }
  )
end

# When someone likes a review
def notify_review_like(liker, review)
  return if liker.id == review.user_id  # Don't notify self

  notification = review.user.notifications.create!(
    notification_type: 'review_like',
    actor: liker,
    review: review,
    message: "#{liker.username} liked your recommendation"
  )

  SendPushNotificationJob.perform_later(
    review.user_id,
    title: 'New Like',
    body: "#{liker.username} liked your recommendation of #{review.song_name}",
    data: {
      type: 'review_like',
      notification_id: notification.id.to_s,
      review_id: review.id.to_s
    }
  )
end

# When someone comments on a review
def notify_review_comment(commenter, comment)
  review = comment.review
  return if commenter.id == review.user_id  # Don't notify self

  notification = review.user.notifications.create!(
    notification_type: 'review_comment',
    actor: commenter,
    review: review,
    comment: comment,
    message: "#{commenter.username} commented on your recommendation"
  )

  SendPushNotificationJob.perform_later(
    review.user_id,
    title: 'New Comment',
    body: "#{commenter.username}: \"#{comment.body.truncate(50)}\"",
    data: {
      type: 'review_comment',
      notification_id: notification.id.to_s,
      review_id: review.id.to_s,
      comment_id: comment.id.to_s
    }
  )
end
```

---

## Part 4: Testing

### 4.1 Test FCM Connection

In Rails console:

```ruby
# Initialize FCM with V1 API
# FCM.new(json_key_path, project_name, http_options = {})
fcm = FCM.new(
  Rails.root.join('config', 'firebase-service-account.json').to_s,
  ENV['FIREBASE_PROJECT_ID'],
  {}
)

# Use a real device token from your database
token = DeviceToken.last.token

# Build the message (V1 API format)
message = {
  token: token,
  notification: {
    title: 'Test',
    body: 'Hello from Rails!'
  },
  data: {
    type: 'test'
  }
}

response = fcm.send_v1(message)
puts response
```

### 4.2 Test Using the Service

```ruby
# Test with your PushNotificationService
user = User.find_by(email: 'test@example.com')
PushNotificationService.new.send_to_user(
  user,
  title: 'Test Notification',
  body: 'This is a test from Rails!',
  data: { type: 'test' }
)
```

### 4.3 Test from Mobile App

1. Build and run the app: `pnpm android`
2. Log in and check Metro logs for "FCM Token: ..."
3. Verify token is saved in database: `DeviceToken.last`
4. Send a test notification from Rails console

### 4.4 Test from Firebase Console

1. Go to Firebase Console → Engage → Messaging
2. Click "Create your first campaign" → "Firebase Notification messages"
3. Enter a title and body
4. Click "Send test message"
5. Enter your device's FCM token (from `DeviceToken.last.token`)
6. Click "Test"

---

## Part 5: iOS Setup (Optional)

For iOS, you'll also need:

1. Apple Developer account ($99/year)
2. Create APNs key in Apple Developer portal
3. Upload APNs key to Firebase Console
4. Add `@react-native-firebase/messaging` iOS configuration
5. Update `ios/Podfile` and run `pod install`

See: https://rnfirebase.io/messaging/usage/ios-setup

---

## Troubleshooting

### Token not registering

- Check that `google-services.json` is in the correct location
- Ensure the package name matches your Firebase app

### Service account authentication failing

- Verify `firebase-service-account.json` exists and is valid JSON
- Check that `FIREBASE_PROJECT_ID` matches your Firebase project
- Ensure the service account has the "Firebase Cloud Messaging API Admin" role

### Notifications not arriving

- Verify the service account JSON is correct
- Check if the device token is valid (not expired)
- Test with Firebase Console's "Messaging" → "Send test message"
- Check Rails logs for FCM response errors

### "PERMISSION_DENIED" errors

- Go to Google Cloud Console → APIs & Services → Enable APIs
- Enable "Firebase Cloud Messaging API" (not the legacy one)
- Ensure your service account has proper IAM roles

### "INVALID_ARGUMENT" errors

- The device token may be malformed or from a different Firebase project
- Verify the token was generated by the same Firebase project

### Background notifications not working

- Android: Check battery optimization settings
- Ensure the app has notification permissions

---

## Security Considerations

1. **Never commit the service account JSON** to version control - add it to `.gitignore`
2. **Use environment variables** for the service account in production (Heroku, Railway, etc.)
3. **Validate user ownership** before sending notifications
4. **Rate limit** notification sending to prevent abuse
5. **Clean up old tokens** periodically (tokens expire/change)
6. **Restrict service account permissions** - only grant Firebase Cloud Messaging roles

---

## Migration from Legacy API

If you were using the legacy API with a Server Key:

1. Delete the `FIREBASE_SERVER_KEY` environment variable
2. Create a service account as described in section 1.3
3. Add `FIREBASE_PROJECT_ID` environment variable
4. Update `PushNotificationService` to use the new initialization
5. The message format is slightly different - see section 3.5

---

## Resources

- [Firebase Cloud Messaging V1 API Docs](https://firebase.google.com/docs/cloud-messaging/migrate-v1)
- [FCM V1 HTTP Protocol](https://firebase.google.com/docs/reference/fcm/rest/v1/projects.messages/send)
- [React Native Firebase](https://rnfirebase.io/messaging/usage)
- [FCM Ruby Gem](https://github.com/decision-labs/fcm)
