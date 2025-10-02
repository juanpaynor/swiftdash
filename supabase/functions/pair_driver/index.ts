// Enhanced Pair Driver Edge Function with Proximity Matching
// Finds closest available drivers and assigns directly to delivery
// NOTE: This is a Deno Edge Function - VS Code errors about imports are expected
// The code runs perfectly in Supabase Edge Runtime (Deno environment)

import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

interface PairRequest {
  deliveryId: string;
}

interface DriverProfile {
  driver_id: string;
  distance: number;
  is_online: boolean;
  is_available: boolean;
  current_latitude: number;
  current_longitude: number;
  location_updated_at: string;
}

serve(async (req: Request) => {
  try {
    if (req.method !== "POST") return new Response("Only POST", { status: 405 });

    const body = (await req.json()) as PairRequest;
    if (!body?.deliveryId) return new Response("Missing deliveryId", { status: 400 });

    const SUPABASE_URL = (globalThis as any).Deno?.env?.get("SUPABASE_URL");
    const SUPABASE_ANON_KEY = (globalThis as any).Deno?.env?.get("SUPABASE_ANON_KEY");
    if (!SUPABASE_URL || !SUPABASE_ANON_KEY) return new Response("Missing Supabase env", { status: 500 });

    const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
      global: { headers: { Authorization: req.headers.get("Authorization") ?? "" } },
    });

    // Verify auth
    const { data: authData, error: authErr } = await supabase.auth.getUser();
    if (authErr || !authData?.user) return new Response("Unauthorized", { status: 401 });

    // Get delivery details for proximity calculation
    const { data: delivery, error: deliveryErr } = await supabase
      .from('deliveries')
      .select('pickup_latitude, pickup_longitude, status, driver_id')
      .eq('id', body.deliveryId)
      .single();

    if (deliveryErr || !delivery) {
      console.error('Delivery not found:', deliveryErr);
      return new Response("Delivery not found", { status: 404 });
    }

    // Only proceed if delivery is pending (no driver assigned)
    if (delivery.status !== 'pending' || delivery.driver_id) {
      return new Response(JSON.stringify({ 
        ok: false, 
        message: `Delivery already assigned or status is ${delivery.status}` 
      }), {
        headers: { 'content-type': 'application/json' },
        status: 400,
      });
    }

    // Find closest available drivers using PostGIS distance calculation
    const { data: drivers, error: driversErr } = await supabase
      .rpc('find_nearest_drivers', {
        pickup_lat: delivery.pickup_latitude,
        pickup_lng: delivery.pickup_longitude,
        max_distance_km: 50, // 50km radius
        limit_count: 5
      });

    if (driversErr) {
      console.error('Error finding drivers with PostGIS, using fallback:', driversErr);
      // Fallback to simple query without PostGIS if function doesn't exist
      const { data: fallbackDrivers, error: fallbackErr } = await supabase
        .from('driver_profiles')
        .select(`
          driver_id, current_latitude, current_longitude, is_online, is_available, 
          location_updated_at, is_verified, name, profile_picture_url, 
          vehicle_model, ltfrb_number, rating, total_rides
        `)
        .eq('is_online', true)
        .eq('is_available', true)
        .eq('is_verified', true) // Only verified drivers
        .not('current_latitude', 'is', null)
        .not('current_longitude', 'is', null)
        .limit(10);

      if (fallbackErr || !fallbackDrivers?.length) {
        return new Response(JSON.stringify({ 
          ok: false, 
          message: "No available drivers found" 
        }), {
          headers: { 'content-type': 'application/json' },
          status: 404,
        });
      }

      // Calculate distance manually for fallback
      const driversWithDistance = fallbackDrivers.map((driver: any) => {
        const distance = calculateDistance(
          delivery.pickup_latitude, delivery.pickup_longitude,
          driver.current_latitude, driver.current_longitude
        );
        return { ...driver, distance };
      }).sort((a: any, b: any) => a.distance - b.distance).slice(0, 5);

      console.log(`Found ${driversWithDistance.length} drivers (fallback method)`);
      
      // Assign to closest driver
      const closestDriver = driversWithDistance[0];
      await assignDriverToDelivery(supabase, body.deliveryId, closestDriver.driver_id);
      
      return new Response(JSON.stringify({ 
        ok: true, 
        delivery_id: body.deliveryId,
        assigned_driver_id: closestDriver.driver_id,
        drivers_found: driversWithDistance.length,
        closest_driver_distance: closestDriver.distance
      }), {
        headers: { 'content-type': 'application/json' },
        status: 200,
      });
    }

    if (!drivers?.length) {
      return new Response(JSON.stringify({ 
        ok: false, 
        message: "No available drivers found" 
      }), {
        headers: { 'content-type': 'application/json' },
        status: 404,
      });
    }

    console.log(`Found ${drivers.length} drivers within 50km radius`);
    
    // Assign to closest driver
    const closestDriver = drivers[0];
    await assignDriverToDelivery(supabase, body.deliveryId, closestDriver.driver_id);

    return new Response(JSON.stringify({ 
      ok: true, 
      delivery_id: body.deliveryId,
      assigned_driver_id: closestDriver.driver_id,
      drivers_found: drivers.length,
      closest_driver_distance: closestDriver.distance || 0
    }), {
      headers: { 'content-type': 'application/json' },
      status: 200,
    });

  } catch (e) {
    console.error('Pair driver error:', e);
    return new Response("Internal error", { status: 500 });
  }
});

// Assign driver to delivery and update status
async function assignDriverToDelivery(supabase: any, deliveryId: string, driverId: string) {
  const { error } = await supabase
    .from('deliveries')
    .update({
      driver_id: driverId,
      status: 'driver_assigned',
      updated_at: new Date().toISOString()
    })
    .eq('id', deliveryId);
  
  if (error) {
    console.error(`Failed to assign driver ${driverId} to delivery ${deliveryId}:`, error);
    throw error;
  }
  
  // Set driver as unavailable while on delivery
  await supabase
    .from('driver_profiles')
    .update({ is_available: false })
    .eq('driver_id', driverId);
  
  console.log(`Successfully assigned driver ${driverId} to delivery ${deliveryId}`);
}

// Record earnings when delivery is completed (called from delivery status updates)
async function recordDeliveryEarnings(supabase: any, deliveryId: string) {
  try {
    // Get delivery details with vehicle type pricing
    const { data: deliveryData, error: deliveryError } = await supabase
      .from('deliveries')
      .select(`
        driver_id, total_price, distance_km, vehicle_type_id,
        vehicle_types!inner(base_price, price_per_km)
      `)
      .eq('id', deliveryId)
      .single();

    if (deliveryError || !deliveryData) {
      console.error('Error fetching delivery for earnings:', deliveryError);
      return;
    }

    const baseEarnings = deliveryData.vehicle_types.base_price;
    const distanceEarnings = deliveryData.distance_km * deliveryData.vehicle_types.price_per_km;
    const totalEarnings = baseEarnings + distanceEarnings;

    // Record earnings
    const { error: earningsError } = await supabase
      .from('driver_earnings')
      .insert({
        driver_id: deliveryData.driver_id,
        delivery_id: deliveryId,
        base_earnings: baseEarnings,
        distance_earnings: distanceEarnings,
        surge_earnings: 0, // TODO: Add surge pricing logic if needed
        tips: 0, // Customer can add tips later
        total_earnings: totalEarnings,
        earnings_date: new Date().toISOString().split('T')[0]
      });

    if (earningsError) {
      console.error('Error recording driver earnings:', earningsError);
    } else {
      console.log(`Recorded ₱${totalEarnings} earnings for driver ${deliveryData.driver_id}`);
    }

    // Set driver as available again
    await supabase
      .from('driver_profiles')
      .update({ is_available: true })
      .eq('driver_id', deliveryData.driver_id);

    // Trigger tip prompt for customer
    await supabase
      .from('delivery_events')
      .insert({
        delivery_id: deliveryId,
        customer_id: deliveryData.customer_id,
        driver_id: deliveryData.driver_id,
        event_type: 'tip_prompt',
        event_data: {
          delivery_total: totalEarnings,
          driver_name: deliveryData.driver_name || 'Your driver'
        },
        processed: false
      });

  } catch (error) {
    console.error('Error in recordDeliveryEarnings:', error);
  }
}

// Haversine formula for distance calculation (fallback)
function calculateDistance(lat1: number, lon1: number, lat2: number, lon2: number): number {
  const R = 6371; // Earth's radius in kilometers
  const dLat = (lat2 - lat1) * Math.PI / 180;
  const dLon = (lon2 - lon1) * Math.PI / 180;
  const a = 
    Math.sin(dLat/2) * Math.sin(dLat/2) +
    Math.cos(lat1 * Math.PI / 180) * Math.cos(lat2 * Math.PI / 180) *
    Math.sin(dLon/2) * Math.sin(dLon/2);
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1-a));
  return R * c;
}
