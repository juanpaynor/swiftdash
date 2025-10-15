// Cron Job: Assign Scheduled Drivers
// Runs every 5 minutes to find scheduled deliveries that need driver assignment
// Assigns drivers 15 minutes before scheduled pickup time
// Created: October 14, 2025

import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

serve(async (req: Request) => {
  try {
    console.log('🕐 Running assign_scheduled_drivers cron job...');

    const SUPABASE_URL = (globalThis as any).Deno?.env?.get("SUPABASE_URL");
    const SUPABASE_SERVICE_KEY = (globalThis as any).Deno?.env?.get("SUPABASE_SERVICE_ROLE_KEY");

    if (!SUPABASE_URL || !SUPABASE_SERVICE_KEY) {
      console.error('❌ Missing environment variables');
      return new Response("Missing environment variables", { status: 500 });
    }

    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY);

    // ==========================================
    // Find scheduled deliveries needing assignment
    // ==========================================
    // Optimized query:
    // - is_scheduled = TRUE
    // - status = 'pending'
    // - driver_id IS NULL
    // - scheduled_pickup_time between NOW and NOW + 10 minutes
    // 
    // Why 10 minutes? Cron runs every 5 min, so checking 0-10 min ahead
    // catches everything between 5-10 min before pickup time.
    // This drastically reduces rows scanned and keeps us under free tier limits.
    
    const now = new Date();
    const tenMinutesFromNow = new Date(Date.now() + 10 * 60 * 1000);

    console.log(`⏰ Checking deliveries between ${now.toISOString()} and ${tenMinutesFromNow.toISOString()}`);

    const { data: scheduledDeliveries, error } = await supabase
      .from('deliveries')
      .select('id, scheduled_pickup_time') // Only fetch what we need (optimization)
      .eq('is_scheduled', true)
      .eq('status', 'pending')
      .is('driver_id', null)
      .gte('scheduled_pickup_time', now.toISOString()) // Not in the past
      .lte('scheduled_pickup_time', tenMinutesFromNow.toISOString()); // Within next 10 min

    if (error) {
      console.error('❌ Error fetching scheduled deliveries:', error);
      return new Response(JSON.stringify({ error: error.message }), {
        status: 500,
        headers: { 'content-type': 'application/json' }
      });
    }

    if (!scheduledDeliveries || scheduledDeliveries.length === 0) {
      console.log('✅ No scheduled deliveries need driver assignment');
      return new Response(JSON.stringify({
        message: 'No deliveries to assign',
        checked_at: new Date().toISOString(),
        found: 0,
      }), {
        status: 200,
        headers: { 'content-type': 'application/json' }
      });
    }

    console.log(`📋 Found ${scheduledDeliveries.length} scheduled deliveries ready for assignment:`);
    scheduledDeliveries.forEach(d => {
      console.log(`   - Delivery ${d.id} scheduled for ${d.scheduled_pickup_time}`);
    });

    // ==========================================
    // Call pair_driver for each delivery
    // ==========================================
    const results = [];
    
    for (const delivery of scheduledDeliveries) {
      try {
        console.log(`🚗 Attempting to pair driver for delivery ${delivery.id}...`);

        // Call pair_driver edge function
        const { data, error: pairError } = await supabase.functions.invoke('pair_driver', {
          body: { deliveryId: delivery.id }
        });

        if (pairError) {
          console.error(`❌ Error pairing driver for ${delivery.id}:`, pairError);
          results.push({
            deliveryId: delivery.id,
            scheduledTime: delivery.scheduled_pickup_time,
            success: false,
            error: pairError.message,
          });
        } else {
          console.log(`✅ Successfully processed delivery ${delivery.id}`);
          results.push({
            deliveryId: delivery.id,
            scheduledTime: delivery.scheduled_pickup_time,
            success: data?.ok || false,
            message: data?.message,
            driverId: data?.offered_driver_id,
          });
        }

      } catch (e) {
        console.error(`❌ Exception pairing driver for ${delivery.id}:`, e);
        results.push({
          deliveryId: delivery.id,
          scheduledTime: delivery.scheduled_pickup_time,
          success: false,
          error: e.message,
        });
      }
    }

    // ==========================================
    // Summary
    // ==========================================
    const successful = results.filter(r => r.success).length;
    const failed = results.length - successful;

    console.log(`📊 Assignment complete: ${successful} successful, ${failed} failed`);

    return new Response(JSON.stringify({
      processed: scheduledDeliveries.length,
      successful,
      failed,
      results,
      checked_at: new Date().toISOString(),
    }), {
      status: 200,
      headers: { 'content-type': 'application/json' }
    });

  } catch (error) {
    console.error('❌ Error in assign_scheduled_drivers:', error);
    return new Response(JSON.stringify({ error: error.message }), {
      status: 500,
      headers: { 'content-type': 'application/json' }
    });
  }
});
