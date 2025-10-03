Realtime subscribe examples (SwiftDash)

This folder contains minimal examples to help you test the new realtime conventions:
- Canonical channel: `driver-location-{deliveryId}`
- Event name: `location_update`

Files:
- `js/subscribe.js` — Node example using @supabase/supabase-js to subscribe to broadcasts

Requirements:
- Node 18+ (or your Node runtime)
- Install dependencies: `npm install @supabase/supabase-js dotenv`

Environment variables (create a `.env` file in this folder):

```
SUPABASE_URL=https://your-project-ref.supabase.co
SUPABASE_ANON_KEY=your_anon_or_service_key
DELIVERY_ID=your-test-delivery-uuid
```

Usage:

```powershell
cd examples\realtime-subscribe
npm install
node js\subscribe.js
```

Notes:
- Ensure your Supabase project's Realtime is enabled and your key has permission to subscribe.
- For RLS-protected data, run the subscriber as an authenticated user (use a session token) or use a test anon key with appropriate RLS in your dev project.
- This is a minimal subscriber only. A driver-side publisher should broadcast with the event name `location_update` on channel `driver-location-{deliveryId}` using the canonical JSON payload in the project docs.
