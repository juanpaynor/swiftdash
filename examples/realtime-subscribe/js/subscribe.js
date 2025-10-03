// Minimal subscriber example using @supabase/supabase-js v2
// Install: npm install @supabase/supabase-js dotenv

import { createClient } from '@supabase/supabase-js';
import dotenv from 'dotenv';
dotenv.config();

const SUPABASE_URL = process.env.SUPABASE_URL;
const SUPABASE_KEY = process.env.SUPABASE_ANON_KEY;
const DELIVERY_ID = process.env.DELIVERY_ID;

if (!SUPABASE_URL || !SUPABASE_KEY || !DELIVERY_ID) {
  console.error('Please set SUPABASE_URL, SUPABASE_ANON_KEY and DELIVERY_ID in .env');
  process.exit(1);
}

const supabase = createClient(SUPABASE_URL, SUPABASE_KEY, {
  realtime: { params: { eventsPerSecond: 100 } }
});

async function start() {
  const channelName = `driver-location-${DELIVERY_ID}`;
  console.log('Subscribing to', channelName);

  const channel = supabase.channel(channelName)
    .on('broadcast', { event: 'location_update' }, ({ payload }) => {
      console.log('Location update received:', payload);
    });

  await channel.subscribe();

  console.log('Subscribed. Waiting for broadcasts... (ctrl+c to exit)');
}

start().catch(err => {
  console.error('Failed to subscribe:', err);
  process.exit(1);
});
