# 📱 Push Notifications Implementation Plan
## Firebase Cloud Messaging (FCM) for SwiftDash Customer App

**Status**: 📌 Planning Phase - Ready to Implement  
**Created**: October 29, 2025  
**Estimated Time**: ~3.5 hours  

---

## 📋 Overview

Implement real-time push notifications for Android and iOS using Firebase Cloud Messaging (FCM) to keep customers informed about their delivery status even when the app is closed or in the background.

**Current State**:
- ✅ Packages already installed: `firebase_messaging: ^15.1.3`, `flutter_local_notifications: ^18.0.1`
- ✅ Real-time updates via Ably (when app is open)
- ❌ No push notifications when app is closed/background

**Goal**: Hybrid approach using Ably for real-time (app open) + FCM for push (app closed)

---

## 🎯 Notification Strategy

### **When to Use Ably (Real-time)**
- App is open and user is viewing tracking screen
- Live driver location updates
- Chat messages while actively chatting

### **When to Use FCM (Push)**
- App is closed or in background
- Critical delivery milestones
- Driver arrival notifications
- Chat messages when not in app

---

## 📋 PHASE 1: Firebase Project Setup (15-20 min)

### 1.1 Create Firebase Project
- [ ] Go to [Firebase Console](https://console.firebase.google.com/)
- [ ] Create new project: `swiftdash-delivery` (or use existing)
- [ ] Enable Google Analytics (optional)

### 1.2 Add Android App
- [ ] Package name: **TODO: Get from `android/app/build.gradle`**
- [ ] Download `google-services.json`
- [ ] Place in `android/app/` directory
- [ ] Enable Cloud Messaging API

### 1.3 Add iOS App (if deploying iOS)
- [ ] Bundle ID: **TODO: Get from Xcode project**
- [ ] Download `GoogleService-Info.plist`
- [ ] Place in `ios/Runner/` directory
- [ ] Generate APNs Auth Key from Apple Developer Console
- [ ] Upload APNs key to Firebase Console

### 1.4 Get Firebase Credentials
- [ ] Copy **FCM Server Key** (for backend)
- [ ] Copy **Sender ID**
- [ ] Save credentials securely

---

## 📋 PHASE 2: Flutter Configuration (20-30 min)

### 2.1 Android Configuration

**File**: `android/build.gradle`
```gradle
buildscript {
    dependencies {
        classpath 'com.google.gms:google-services:4.4.0'
    }
}
```

**File**: `android/app/build.gradle`
```gradle
// Add at bottom
apply plugin: 'com.google.gms.google-services'
```

**File**: `android/app/src/main/AndroidManifest.xml`
```xml
<application>
    <!-- Add notification channel -->
    <meta-data
        android:name="com.google.firebase.messaging.default_notification_channel_id"
        android:value="swiftdash_delivery_channel" />
</application>
```

### 2.2 iOS Configuration

**File**: `ios/Runner/AppDelegate.swift`
- Add Firebase initialization
- Request notification permissions

**File**: `ios/Runner/Info.plist`
- Add notification permission descriptions

### 2.3 Create Notification Service

**New File**: `lib/services/notification_service.dart`

**Responsibilities**:
- Initialize FCM
- Request permissions (Android 13+, iOS)
- Get and save FCM token to Supabase
- Handle foreground notifications (display banner)
- Handle background notifications
- Handle notification taps (deep linking)
- Refresh token on updates

---

## 📋 PHASE 3: Database Schema (10 min)

### 3.1 Migration: Add FCM Token Storage

**New File**: `supabase/migrations/add_fcm_tokens.sql`

```sql
-- Add FCM token to customers
ALTER TABLE customer_profiles
ADD COLUMN fcm_token TEXT NULL,
ADD COLUMN fcm_token_updated_at TIMESTAMP WITH TIME ZONE NULL;

-- Index for faster lookups
CREATE INDEX idx_customer_profiles_fcm_token 
ON customer_profiles(fcm_token) 
WHERE fcm_token IS NOT NULL;

-- Add to drivers (future driver app)
ALTER TABLE driver_profiles
ADD COLUMN fcm_token TEXT NULL,
ADD COLUMN fcm_token_updated_at TIMESTAMP WITH TIME ZONE NULL;

-- Function to update FCM token
CREATE OR REPLACE FUNCTION update_fcm_token(
  user_id UUID,
  new_token TEXT
)
RETURNS void AS $$
BEGIN
  UPDATE customer_profiles
  SET 
    fcm_token = new_token,
    fcm_token_updated_at = NOW()
  WHERE id = user_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to clear token on logout
CREATE OR REPLACE FUNCTION clear_fcm_token(user_id UUID)
RETURNS void AS $$
BEGIN
  UPDATE customer_profiles
  SET 
    fcm_token = NULL,
    fcm_token_updated_at = NULL
  WHERE id = user_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
```

---

## 📋 PHASE 4: Backend Integration (45-60 min)

### 4.1 Environment Variables

**Add to `.env`**:
```env
# Firebase Cloud Messaging
FCM_SERVER_KEY=your_fcm_server_key_here
FCM_SENDER_ID=your_sender_id_here
```

**Add to Supabase Secrets**:
```bash
supabase secrets set FCM_SERVER_KEY=your_key_here
```

### 4.2 Create FCM Edge Function

**New File**: `supabase/functions/send-push-notification/index.ts`

```typescript
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const FCM_SERVER_KEY = Deno.env.get('FCM_SERVER_KEY')!
const FCM_ENDPOINT = 'https://fcm.googleapis.com/fcm/send'

interface NotificationPayload {
  customer_id: string
  title: string
  body: string
  data?: {
    delivery_id?: string
    screen?: 'tracking' | 'receipt' | 'chat'
    action?: string
  }
}

serve(async (req) => {
  try {
    const payload: NotificationPayload = await req.json()
    
    // Get customer's FCM token
    const supabase = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    )
    
    const { data: customer } = await supabase
      .from('customer_profiles')
      .select('fcm_token')
      .eq('id', payload.customer_id)
      .single()
    
    if (!customer?.fcm_token) {
      throw new Error('No FCM token found for customer')
    }
    
    // Send notification via FCM
    const response = await fetch(FCM_ENDPOINT, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `key=${FCM_SERVER_KEY}`
      },
      body: JSON.stringify({
        to: customer.fcm_token,
        priority: 'high',
        notification: {
          title: payload.title,
          body: payload.body,
          sound: 'default',
          badge: '1'
        },
        data: payload.data || {}
      })
    })
    
    const result = await response.json()
    return new Response(JSON.stringify(result), { status: 200 })
    
  } catch (error) {
    return new Response(JSON.stringify({ error: error.message }), { status: 500 })
  }
})
```

### 4.3 Update Existing Edge Functions

**Update**: `supabase/functions/pair_driver/index.ts`

Add notification when driver accepts:
```typescript
// After driver accepts delivery
await fetch('https://your-project.supabase.co/functions/v1/send-push-notification', {
  method: 'POST',
  headers: {
    'Authorization': `Bearer ${SUPABASE_ANON_KEY}`,
    'Content-Type': 'application/json'
  },
  body: JSON.stringify({
    customer_id: delivery.customer_id,
    title: 'Driver Found! 🚗',
    body: `${driver.name} is heading to pickup location`,
    data: {
      delivery_id: delivery.id,
      screen: 'tracking',
      status: 'driver_assigned'
    }
  })
})
```

**Create**: Database trigger for status updates
```sql
-- Trigger to send notifications on status change
CREATE OR REPLACE FUNCTION notify_delivery_status_change()
RETURNS TRIGGER AS $$
BEGIN
  -- Call edge function for critical status updates
  IF NEW.status IN ('driver_assigned', 'pickup_arrived', 'package_collected', 'in_transit', 'delivered') THEN
    PERFORM net.http_post(
      url := 'https://your-project.supabase.co/functions/v1/send-push-notification',
      body := jsonb_build_object(
        'customer_id', NEW.customer_id,
        'title', get_notification_title(NEW.status),
        'body', get_notification_body(NEW.status),
        'data', jsonb_build_object(
          'delivery_id', NEW.id,
          'screen', 'tracking',
          'status', NEW.status
        )
      )
    );
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER delivery_status_notification
AFTER UPDATE OF status ON deliveries
FOR EACH ROW
WHEN (OLD.status IS DISTINCT FROM NEW.status)
EXECUTE FUNCTION notify_delivery_status_change();
```

---

## 📋 PHASE 5: Notification Types & Channels (15-20 min)

### 5.1 Define Notification Channels

**New File**: `lib/constants/notification_channels.dart`

```dart
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationChannels {
  static const driverUpdates = AndroidNotificationChannel(
    'driver_updates',
    'Driver Updates',
    description: 'Real-time driver location and status',
    importance: Importance.high,
    playSound: true,
    enableVibration: true,
  );
  
  static const deliveryStatus = AndroidNotificationChannel(
    'delivery_status',
    'Delivery Status',
    description: 'Pickup, delivery, completion updates',
    importance: Importance.defaultImportance,
  );
  
  static const chatMessages = AndroidNotificationChannel(
    'chat_messages',
    'Chat Messages',
    description: 'Messages from your driver',
    importance: Importance.high,
    playSound: true,
  );
}
```

### 5.2 Notification Templates

| **Event** | **Title** | **Body** | **Priority** | **Sound** |
|-----------|-----------|----------|--------------|-----------|
| Driver assigned | "Driver Found! 🚗" | "{Name} is heading to pickup" | High | Yes |
| Driver at pickup | "Driver Arrived 📍" | "Driver at {Address}" | High | Yes |
| Package collected | "Package Picked Up 📦" | "Your package is on the way!" | Default | No |
| In transit | "On The Way! 🚚" | "Estimated arrival in {ETA}" | High | Yes |
| 5 min away | "Driver Approaching 📍" | "Your driver is 5 minutes away" | High | Yes |
| Delivered | "Delivered! ✅" | "Package delivered successfully" | Default | Yes |
| New chat message | "Message from Driver 💬" | "{Message preview}" | High | Yes |
| Payment success | "Payment Successful 💳" | "₱{Amount} charged" | Default | No |

---

## 📋 PHASE 6: Deep Linking & Navigation (20-30 min)

### 6.1 Handle Notification Taps

**Update**: `lib/services/notification_service.dart`

```dart
void _handleNotificationTap(RemoteMessage message) {
  final data = message.data;
  final screen = data['screen'];
  final deliveryId = data['delivery_id'];
  
  // Navigate based on data
  switch (screen) {
    case 'tracking':
      navigatorKey.currentState?.pushNamed(
        '/tracking/$deliveryId'
      );
      break;
    case 'chat':
      // Open tracking with chat modal
      navigatorKey.currentState?.pushNamed(
        '/tracking/$deliveryId',
        arguments: {'openChat': true}
      );
      break;
    case 'receipt':
      navigatorKey.currentState?.pushNamed(
        '/receipt/$deliveryId'
      );
      break;
  }
}
```

### 6.2 Update Router

**Update**: `lib/router.dart`
- Add global navigator key for deep linking
- Handle app launch from notification

---

## 📋 PHASE 7: Testing Strategy (30-40 min)

### 7.1 Test Cases

**Scenario 1: Foreground Notification**
- [ ] App open on tracking screen
- [ ] Trigger status change
- [ ] Banner notification appears at top
- [ ] Notification auto-dismisses after 3s

**Scenario 2: Background Notification**
- [ ] App minimized to background
- [ ] Trigger status change
- [ ] System notification appears
- [ ] Tap notification → Opens tracking screen

**Scenario 3: App Closed**
- [ ] Force close app
- [ ] Trigger status change
- [ ] Notification appears
- [ ] Tap → App launches to tracking screen

**Scenario 4: Multiple Notifications**
- [ ] Send 3 notifications quickly
- [ ] Only latest or grouped notification shown
- [ ] No spam

**Scenario 5: Token Management**
- [ ] Login → Token saved to database
- [ ] Logout → Token cleared
- [ ] Token refresh → Updated in database

**Scenario 6: Permissions**
- [ ] First launch → Request permission
- [ ] Permission denied → Graceful fallback
- [ ] Permission granted → Notifications work

### 7.2 Testing Tools

- **Firebase Console**: Cloud Messaging → Send test message
- **Postman**: Test Edge Function directly
- **Supabase Dashboard**: Verify token storage
- **Android Studio Logcat**: Debug FCM messages
- **Xcode Console**: Debug iOS notifications

---

## 📋 PHASE 8: Production Optimization (15-20 min)

### 8.1 Rate Limiting

```typescript
// Don't spam users - max 1 notification per minute
const RATE_LIMIT_SECONDS = 60

async function canSendNotification(customerId: string): Promise<boolean> {
  const lastSent = await redis.get(`notification:${customerId}:last_sent`)
  if (lastSent && Date.now() - parseInt(lastSent) < RATE_LIMIT_SECONDS * 1000) {
    return false
  }
  return true
}
```

### 8.2 Smart Notifications

```typescript
// Don't send push if user is actively viewing tracking screen
const isUserActive = await checkAblyPresence(deliveryId, customerId)
if (isUserActive) {
  console.log('User is active - skip push notification')
  return
}
```

### 8.3 Analytics

Track in Supabase:
- [ ] Notification sent count
- [ ] Notification delivered count
- [ ] Notification opened count
- [ ] Notification open rate by type

---

## 🎯 Critical Notification Events

### **High Priority** (Must send immediately)
1. ✅ Driver assigned (from `pair_driver` function)
2. 📍 Driver at pickup location
3. 📦 Package collected
4. 🚚 Driver on the way to delivery
5. 📍 Driver arriving (5 min away)
6. ✅ Delivered

### **Medium Priority** (Can batch or delay)
7. 💬 New chat message (if app closed)
8. 💳 Payment successful
9. ⭐ Request rating (after delivery)

### **Low Priority** (Can skip if recent notification)
10. 🎁 Promotional offers
11. 📊 Delivery summary

---

## 🔐 Security Considerations

1. **FCM Server Key**: Store in Supabase secrets (not in code)
2. **Token Validation**: Verify tokens before sending
3. **User Privacy**: Don't send sensitive data in notification body
4. **Authorization**: Only send to customer who owns delivery
5. **Rate Limiting**: Prevent notification spam/abuse

---

## 📊 Success Metrics

| **Metric** | **Target** | **How to Measure** |
|------------|------------|-------------------|
| Notification Delivery Rate | >95% | FCM success rate |
| Notification Open Rate | >40% | Track opens in analytics |
| Permission Grant Rate | >80% | Track permission requests |
| Average Response Time | <30s | Time from trigger to delivery |
| User Complaints | <1% | Support tickets |

---

## 🚀 Implementation Timeline

| **Phase** | **Time** | **Dependency** |
|-----------|----------|----------------|
| Phase 1: Firebase Setup | 20 min | Firebase account, Apple Dev (iOS) |
| Phase 2: Flutter Config | 30 min | Phase 1 ✅ |
| Phase 3: Database | 10 min | Supabase access |
| Phase 4: Backend | 60 min | Phase 3 ✅ |
| Phase 5: Channels | 20 min | Phase 2 ✅ |
| Phase 6: Deep Links | 30 min | Phase 2 ✅ |
| Phase 7: Testing | 40 min | All phases ✅ |
| Phase 8: Polish | 20 min | Phase 7 ✅ |
| **TOTAL** | **~3.5 hours** | |

---

## ❓ Pre-Implementation Checklist

- [ ] **Firebase Project**: Do you have one already?
- [ ] **Android Package Name**: Get from `android/app/build.gradle`
- [ ] **iOS Bundle ID**: Get from Xcode (if deploying iOS)
- [ ] **Apple Developer Account**: Required for iOS APNs
- [ ] **Priority Notifications**: Which events are most critical?
- [ ] **Platform**: Start with Android only or both?

---

## 📝 Notes

- **Current Setup**: Already using Ably for real-time updates when app is open
- **Packages Installed**: firebase_messaging ^15.1.3, flutter_local_notifications ^18.0.1
- **Hybrid Strategy**: Ably (app open) + FCM (app closed) for best UX
- **Deep Linking**: Router already set up with GoRouter
- **Delivery Stages**: 7 stages mapped from database status

---

## 🔗 Resources

- [Firebase Console](https://console.firebase.google.com/)
- [FCM Documentation](https://firebase.google.com/docs/cloud-messaging)
- [Flutter Firebase Messaging](https://firebase.flutter.dev/docs/messaging/overview)
- [APNs Key Setup](https://developer.apple.com/documentation/usernotifications)
- [Supabase Edge Functions](https://supabase.com/docs/guides/functions)

---

**Status**: 📌 Ready to implement when approved  
**Last Updated**: October 29, 2025  
**Contact**: Review this plan before starting implementation
