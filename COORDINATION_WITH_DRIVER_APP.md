# Coordination: Customer App changes for Optimized Realtime Migration

Date: 2025-10-03

This file documents what the Customer App changed, why, and any actions required on Supabase or by the Driver App team. Use this as the coordination message when communicating with the Driver App AI.

---

## Summary of changes applied to Customer App

1. Realtime subscriptions and streaming now rely on the new lightweight `driver_current_status` table and the broadcast channels `driver-location-{deliveryId}`.
2. `DeliveryService.getDriverLocation` and `DeliveryService.streamDriverLocation` were updated to use `driver_current_status` instead of `driver_profiles`.
3. Added `lib/services/realtime_service.dart` and `lib/widgets/delivery_tracking_widget.dart` to subscribe to broadcast channels and delivery updates.
4. Added SQL helpers and examples under `sql/` and `examples/realtime-subscribe/` for testing.

---

## What I changed in the app (technical)

- `lib/services/delivery_service.dart`
  - `getDriverLocation` now queries `driver_current_status` for last-known location and status.
  - `streamDriverLocation` now streams `driver_current_status:driver_id=eq.{driverId}` for live updates.

- `lib/services/realtime_service.dart`
  - Simple wrapper for subscribing to `driver-location-{deliveryId}` broadcasts and delivery table updates.

- `lib/widgets/delivery_tracking_widget.dart`
  - A test widget that subscribes to broadcasts and shows a minimal live tracking card.

- `sql/accept_delivery_offer.sql`, `sql/ensure_realtime_publication.sql`, `sql/fix_rls_and_grants.sql`
  - Utilities and fixes for Supabase deployment (please review and run as admin where needed).

- `examples/realtime-subscribe/js/subscribe.js`
  - Node example to subscribe to broadcast events for manual testing.

---

## Supabase actions I may need you to perform (please confirm when done)

1. Run `sql/fix_rls_and_grants.sql` in Supabase SQL Editor (admin) to tighten RLS policies and remove DELETE grants from `authenticated` role.
2. Confirm `driver_current_status`, `driver_location_history`, and `analytics_events` tables exist and are in the `supabase_realtime` publication. If not, run `sql/ensure_realtime_publication.sql`.
3. Confirm the driver app will broadcast to `driver-location-{deliveryId}` with event `location_update` and canonical JSON fields (driver_id, delivery_id, latitude, longitude, battery_level, timestamp, etc.).
4. If you plan to support public tracking links, confirm whether you want short-lived signed tokens or a server-side proxy endpoint. We haven't implemented public-link flow.

---

## Coordination file for the Driver App team (what to tell them)

Please let the Driver App team know:

- Customer App now reads and streams `driver_current_status` for live location/state. Please ensure drivers update that table (upsert) with last-known location and status.
- For live high-frequency GPS, publish non-persistent broadcasts to channel `driver-location-{deliveryId}` with event name `location_update` and the canonical payload as documented in `CUSTOMER_APP_AI_MESSAGE_OPTIMIZED_REALTIME.md`.
- Driver App should write critical events (pickup/delivery/shift) to `driver_location_history` (or the server can write validated rows). RLS requires authenticated driver sessions for client writes.

---

## Next steps I will take (unless you want me to stop)

- Integrate `DeliveryTrackingWidget` into the active tracking screen (`lib/screens/tracking_screen.dart`) to replace or complement the existing LiveTrackingMap wiring (I can do this next).
- Add a small driver-side publisher example (JS or Dart) that sends `location_update` broadcasts to `driver-location-{deliveryId}` for E2E tests.
- Implement short-lived signed token endpoint if you want public tracking links.

---

If you confirm the Supabase items above (esp. running `fix_rls_and_grants.sql` and ensuring publication), I will proceed to wire the tracking widget into the tracking screen and implement map marker smoothing.