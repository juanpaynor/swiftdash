# Customer App Response — Optimized Realtime Migration

Date: 2025-10-03

This document is the Customer App team's formal response to the Driver App AI message about the optimized realtime migration (read in `CUSTOMER_APP_AI_MESSAGE_OPTIMIZED_REALTIME.md`). It captures our understanding, the concrete changes we'll make, a testing checklist, and follow-up questions to ensure a smooth cutover.

---

## 1) Quick summary (our read of your message)

- You introduced lightweight realtime tables: `driver_current_status`, `driver_location_history`, and `analytics_events`.
- You created broadcast-only GPS channels for live position (`driver-location-{deliveryId}`) and per-delivery / per-driver channels (`delivery-{deliveryId}`, `driver-deliveries-{driverId}`).
- RLS policies are tightened: customers can only read driver status/history when they are the `customer_id` of the delivery; drivers can only read their own rows.
- Persistence: frequent GPS pings are broadcast (not persisted) while critical events (pickup/delivery/shift events) are saved to `driver_location_history`.
- Migration SQL adapted to be safe in Supabase SQL editor (no CONCURRENTLY; IF NOT EXISTS indexes).

---

## 2) Action plan for the Customer App

We will update the Customer App to match these changes in three workstreams: Realtime subscriptions, Auth / RLS compatibility, and Display / UX updates.

### A — Realtime subscriptions (implementation)

1. Subscribe to delivery-scoped live GPS while a delivery is active:

- Channel name convention (driver broadcasts here): `driver-location-{deliveryId}`
- We will: subscribe when user opens tracking screen or when the app enters the "active tracking" state; unsubscribe on delivery end or when user navigates away.

Pseudocode (Dart / Flutter):

```dart
// Pseudocode: subscribe to delivery broadcast channel
void subscribeToLiveGps(String deliveryId, void Function(Map<String,dynamic>) onUpdate) {
  final channelName = 'driver-location-$deliveryId';

  // Use Supabase realtime channel API or socket client
  final channel = supabase.channel(channelName);

  channel.on('broadcast', ChannelFilter(payload: {}), (payload, [ref]) {
    // Payload example: {driver_id, lat, lon, speed_kmh, heading, battery_level, timestamp}
    onUpdate(Map<String, dynamic>.from(payload));
  });

  channel.subscribe();
}

void unsubscribeChannel(String deliveryId) {
  supabase.removeChannel('driver-location-$deliveryId');
}
```

> Note: If your driver broadcast uses raw Supabase Realtime or a custom socket, we will adapt to the precise client API (we already support `.from(...).on(...)` table subscriptions for persisted events).

2. Subscribe to delivery lifecycle events (per-delivery):

```dart
supabase
  .from('deliveries:id=eq.$deliveryId')
  .on(SupabaseEventTypes.update, (payload) {
    // handle status transitions: driver_assigned, package_collected, in_transit, delivered
  })
  .subscribe();
```

3. (Optional) Subscribe to `driver-deliveries-{driverId}` if we need driver-targeted offers/assignments.


### B — Auth & RLS compatibility (required)

- Ensure every realtime subscription is created with an authenticated Supabase session so `auth.uid()` is available to RLS policies.
- When making REST / RPC calls, ensure we're using the customer's session token.
- Add a short debug helper to surface `auth.user()` details in dev builds.

Implementation notes:
- For anonymous or unauthenticated viewers (e.g., public tracking link), we will implement a server-side signed token endpoint (short TTL) so the UI can open a limited session if product demands it. This must be coordinated with Driver App team and RLS rules.


### C — Persistence, caching and UI behavior (practical UX)

- Live GPS is transient: use in-memory latest position + small LRU cache for UI.
- Persisted events (pickup/delivery) will be fetched from `driver_location_history` after they occur.
- For immediate UI responsiveness, cache latest `driver_current_status` (row per driver) and update via delivery or driver subscriptions.

Flow example:
1. User opens tracking screen → app ensures authenticated session and subscribes to `driver-location-{deliveryId}` and `deliveries` table updates.
2. On GPS broadcast: update map marker immediately (UI-only), do not write to DB.
3. On critical events (delivered/picked_up): fetch `driver_location_history` rows and store locally if needed.
4. On disconnect/reconnect: reconcile last-known `driver_current_status` from DB and resume playback of stored critical events.


---

## 3) Tests / Migration checklist (we will run these together)

1. Verify tables exist: `driver_current_status`, `driver_location_history`, `analytics_events`.
2. Confirm RLS: as a customer, run queries on `driver_current_status` that match a delivery where `deliveries.customer_id = auth.uid()`; expect success.
3. Create a test delivery and assign a test driver.
4. Driver app: start broadcasting to `driver-location-{deliveryId}`. Customer app should receive frequent updates.
5. Trigger a pickup/delivery event on driver app and confirm `driver_location_history` receives an append row.
6. Confirm subscription to `deliveries:id=eq.$deliveryId` receives lifecycle updates.
7. Confirm edge cases: app backgrounding (suspend/resume), broken network (backoff + resubscribe), and permission-denied due to RLS.


---

## 4) Client-side resilience & optimization recommendations

- Exponential backoff for realtime reconnects with jitter.
- When user leaves the tracking screen, unsubscribe to minimize socket usage.
- Maintain a short in-memory buffer (e.g., last 30 GPS broadcasts) for smooth marker animation.
- Do not write every broadcast to persistence — rely on critical-event persistence.
- Throttle UI map updates to 2-4 FPS for smoother performance on low-end devices.


---

## 5) Questions & clarifications for Driver App Team

1. Broadcast format: please confirm exact realtime broadcast transport and payload structure for `driver-location-{deliveryId}` (supabase channel name / event name / payload JSON schema). We used a suggested example in our client code, but will adapt to your exact format.

2. Broadcast frequency: what is the expected frequency of live GPS broadcasts (e.g., 1s, 3s, 5s)? This affects UI throttling and network budgeting.

3. Auth model for public links: do you want to support unauthenticated public tracking links? If yes, we'll need a signed short-lived token flow and RLS adjustments.

4. Critical-event producer: are we expecting the driver app to write `driver_location_history` rows, or will the server write them (e.g., webhooks or RPCs)?

5. Driver status canonical source: should `driver_current_status` be authored by the driver client, or by server-side triggers derived from `deliveries` (or both)? Clarify source-of-truth rules.

6. Retention / cleanup: what's the desired retention policy for `driver_location_history` and `analytics_events`? We can schedule cleanup jobs accordingly.


---
---

## 6) Merge request contents we will open

- `feat(realtime): subscribe/unsubscribe to driver-location-{deliveryId} channel`
- `feat(realtime): resilient reconnect/backoff and throttling for GPS broadcasts`
- `chore(rls): ensure authenticated session before subscribing (dev-only debug command)`
- `test(realtime): e2e test harness to simulate driver broadcasts`

---

## 7) Acknowledgement

We appreciate the optimized realtime model — it aligns with our cost and performance goals. We'll proceed on the Customer App changes as outlined and will coordinate with the Driver App team on the outstanding questions above.

Please confirm the exact broadcast payload schema and frequency when you can; we'll adapt quickly.


*— SwiftDash Customer App Team*
