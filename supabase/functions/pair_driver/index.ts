// Enhanced Pair Driver Edge Function with Driver App Integration
// Finds closest available drivers and assigns directly to delivery
// Updated: October 14, 2025 - Multi-stop delivery support with route-based pricing

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
      .select('pickup_latitude, pickup_longitude, status, driver_id, is_scheduled, scheduled_pickup_time')
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

    // ⭐ Check if delivery is scheduled - only assign 15 minutes before pickup
    if (delivery.is_scheduled && delivery.scheduled_pickup_time) {
      const scheduledTime = new Date(delivery.scheduled_pickup_time);
      const now = new Date();
      const fifteenMinutesBeforePickup = new Date(scheduledTime.getTime() - 15 * 60 * 1000);

      console.log(`⏰ Scheduled delivery detected:`);
      console.log(`   Scheduled pickup: ${scheduledTime.toISOString()}`);
      console.log(`   Assignment time: ${fifteenMinutesBeforePickup.toISOString()}`);
      console.log(`   Current time: ${now.toISOString()}`);

      // Don't assign driver yet if it's too early
      if (now < fifteenMinutesBeforePickup) {
        const minutesUntilAssignment = Math.ceil(
          (fifteenMinutesBeforePickup.getTime() - now.getTime()) / (60 * 1000)
        );
        
        console.log(`⏳ Too early for assignment - waiting ${minutesUntilAssignment} minutes`);

        return new Response(JSON.stringify({
          ok: false,
          scheduled: true,
          message: `Scheduled delivery - driver will be assigned ${minutesUntilAssignment} minutes before pickup`,
          scheduled_for: delivery.scheduled_pickup_time,
          assignment_time: fifteenMinutesBeforePickup.toISOString(),
          minutes_until_assignment: minutesUntilAssignment,
        }), {
          status: 200,
          headers: { 'content-type': 'application/json' }
        });
      }

      console.log(`✅ Scheduled delivery ready for driver assignment`);
    }

    console.log(`🔍 Searching for drivers near: ${delivery.pickup_latitude}, ${delivery.pickup_longitude}`);

    // Query using the actual database schema - all data is in driver_profiles
    const { data: availableDrivers, error: driversErr } = await supabase
      .from('driver_profiles')
      .select(`
        id, profile_picture_url, vehicle_model, ltfrb_number, rating, total_deliveries, is_verified,
        current_latitude, current_longitude, is_online, is_available, location_updated_at
      `)
      .eq('is_available', true)                         // Driver is available
      .eq('is_online', true)                            // Driver is online
      .eq('is_verified', true)                          // Only verified drivers
      .not('current_latitude', 'is', null)
      .not('current_longitude', 'is', null)
      .order('location_updated_at', { ascending: false })
      .limit(10);

    console.log(`📊 Available drivers found: ${availableDrivers?.length || 0}`);

    if (driversErr || !availableDrivers?.length) {
      console.error('No available drivers found:', driversErr);
      return new Response(JSON.stringify({ 
        ok: false, 
        message: "No available drivers found - drivers may be offline or busy" 
      }), {
        headers: { 'content-type': 'application/json' },
        status: 404,
      });
    }

    // Calculate distance for all available drivers
    const driversWithDistance = availableDrivers.map((driver: any) => {
      const distance = calculateDistance(
        delivery.pickup_latitude, delivery.pickup_longitude,
        driver.current_latitude, 
        driver.current_longitude
      );
      return { ...driver, distance };
    }).sort((a: any, b: any) => a.distance - b.distance);

    console.log(`📊 Driver distances from pickup (${delivery.pickup_latitude}, ${delivery.pickup_longitude}):`);
    driversWithDistance.slice(0, 5).forEach((d: any, i: number) => {
      console.log(`   ${i + 1}. Driver ${d.id}: ${d.distance.toFixed(2)}km (at ${d.current_latitude}, ${d.current_longitude})`);
    });
    console.log(`🎯 Closest driver: ${driversWithDistance[0]?.id || 'Unknown'} at ${driversWithDistance[0]?.distance?.toFixed(2)}km`);

    // ⚠️ CHECK MAXIMUM RADIUS - don't assign drivers too far away
    const MAX_PICKUP_RADIUS_KM = 6; // Maximum 10km from pickup location
    const closestDriver = driversWithDistance[0];
    
    if (closestDriver.distance > MAX_PICKUP_RADIUS_KM) {
      console.error(`❌ Closest driver is ${closestDriver.distance.toFixed(2)}km away (max: ${MAX_PICKUP_RADIUS_KM}km)`);
      return new Response(JSON.stringify({ 
        ok: false, 
        message: `No drivers available within ${MAX_PICKUP_RADIUS_KM}km of pickup location. Closest driver is ${closestDriver.distance.toFixed(1)}km away.`,
        closest_driver_distance: closestDriver.distance,
        max_radius: MAX_PICKUP_RADIUS_KM
      }), {
        headers: { 'content-type': 'application/json' },
        status: 404,
      });
    }

    // Offer delivery to closest driver with calculated pricing
    await offerDeliveryToDriver(supabase, body.deliveryId, closestDriver.id, delivery.pickup_latitude, delivery.pickup_longitude);
    
    console.log(`📨 Delivery offered to driver: ${closestDriver.id} for delivery: ${body.deliveryId}`);

    return new Response(JSON.stringify({ 
      ok: true, 
      delivery_id: body.deliveryId,
      offered_driver_id: closestDriver.id,
      drivers_found: driversWithDistance.length,
      closest_driver_distance: closestDriver.distance,
      driver_name: 'Driver',
      status: 'driver_offered'
    }), {
      headers: { 'content-type': 'application/json' },
      status: 200,
    });

  } catch (e) {
    console.error('Pair driver error:', e);
    return new Response("Internal error", { status: 500 });
  }
});

// Offer delivery to driver (requires acceptance) with pricing calculation
// Updated: October 14, 2025 - Multi-stop support
async function offerDeliveryToDriver(supabase: any, deliveryId: string, driverId: string, pickupLat: number, pickupLng: number) {
  // First get delivery details to calculate pricing
  const { data: deliveryData, error: deliveryError } = await supabase
    .from('deliveries')
    .select(`
      vehicle_type_id, delivery_latitude, delivery_longitude,
      is_multi_stop, total_stops,
      vehicle_types!inner(base_price, price_per_km, additional_stop_charge)
    `)
    .eq('id', deliveryId)
    .single();

  if (deliveryError || !deliveryData) {
    console.error('Failed to get delivery data for pricing:', deliveryError);
    throw new Error('Cannot calculate pricing');
  }

  let distanceKm = 0;
  
  // Multi-stop deliveries: calculate total route distance through all stops
  if (deliveryData.is_multi_stop) {
    console.log(`📍 Calculating multi-stop route for ${deliveryData.total_stops} stops`);
    
    const { data: stops, error: stopsError } = await supabase
      .from('delivery_stops')
      .select('latitude, longitude, stop_number')
      .eq('delivery_id', deliveryId)
      .order('stop_number');
    
    if (stopsError || !stops || stops.length === 0) {
      console.error('Failed to get stops for multi-stop delivery:', stopsError);
      throw new Error('Cannot calculate multi-stop route');
    }
    
    // Calculate total route distance through all stops
    for (let i = 0; i < stops.length - 1; i++) {
      const segmentDistance = calculateDistance(
        stops[i].latitude, stops[i].longitude,
        stops[i + 1].latitude, stops[i + 1].longitude
      );
      distanceKm += segmentDistance;
      console.log(`  Stop ${i} → Stop ${i + 1}: ${segmentDistance.toFixed(2)}km`);
    }
    
    console.log(`  Total multi-stop distance: ${distanceKm.toFixed(2)}km`);
  } else {
    // Single-stop delivery: pickup to dropoff
    distanceKm = calculateDistance(
      pickupLat, pickupLng,
      deliveryData.delivery_latitude, deliveryData.delivery_longitude
    );
  }

  // Calculate pricing with multi-stop support
  const basePrice = Number(deliveryData.vehicle_types.base_price) || 0;
  const pricePerKm = Number(deliveryData.vehicle_types.price_per_km) || 0;
  const additionalStopCharge = Number(deliveryData.vehicle_types.additional_stop_charge) || 0;
  
  // Multi-stop pricing: charge for each additional stop beyond the first dropoff
  const additionalStops = deliveryData.is_multi_stop ? Math.max(0, (deliveryData.total_stops - 1)) : 0;
  const additionalStopsTotal = additionalStops * additionalStopCharge;
  
  const subtotal = basePrice + (pricePerKm * distanceKm) + additionalStopsTotal;
  
  // Add 12% VAT (Philippine requirement)
  const vatRate = 0.12;
  const vat = subtotal * vatRate;
  const totalAmount = Math.max(1, Math.round((subtotal + vat) * 100) / 100);

  if (deliveryData.is_multi_stop) {
    console.log(`💰 Multi-stop pricing: ${deliveryData.total_stops} stops (${additionalStops} additional), Distance ${distanceKm.toFixed(2)}km, Base ₱${basePrice}, Distance ₱${(pricePerKm * distanceKm).toFixed(2)}, Additional stops ₱${additionalStopsTotal.toFixed(2)}, VAT ₱${vat.toFixed(2)}, Total ₱${totalAmount.toFixed(2)}`);
  } else {
    console.log(`💰 Single-stop pricing: Distance ${distanceKm.toFixed(2)}km, Base ₱${basePrice}, Distance ₱${(pricePerKm * distanceKm).toFixed(2)}, VAT ₱${vat.toFixed(2)}, Total ₱${totalAmount.toFixed(2)}`);
  }

  // Update delivery with driver assignment, status, and calculated pricing
  const { error } = await supabase
    .from('deliveries')
    .update({
      driver_id: driverId,
      status: 'driver_offered',
      distance_km: Math.round(distanceKm * 10) / 10, // Round to 1 decimal
      total_amount: totalAmount,
      updated_at: new Date().toISOString()
    })
    .eq('id', deliveryId);
  
  if (error) {
    console.error(`Failed to offer delivery to driver ${driverId} for delivery ${deliveryId}:`, error);
    throw error;
  }
  
  // Driver stays available until they accept
  // No need to set is_available = false yet
  
  console.log(`Successfully offered delivery ${deliveryId} to driver ${driverId} with pricing ₱${totalAmount}`);
}

// Called when driver accepts the delivery offer
async function acceptDeliveryOffer(supabase: any, deliveryId: string, driverId: string) {
  const { error } = await supabase
    .from('deliveries')
    .update({
      status: 'driver_assigned',  // Now actually assigned
      updated_at: new Date().toISOString()
    })
    .eq('id', deliveryId)
    .eq('driver_id', driverId);
  
  if (error) {
    console.error(`Failed to accept delivery ${deliveryId} by driver ${driverId}:`, error);
    throw error;
  }
  
  // Set driver as busy now that they've accepted
  await supabase
    .from('driver_profiles')
    .update({ 
      is_available: false
    })
    .eq('id', driverId);
  
  console.log(`Driver ${driverId} accepted delivery ${deliveryId}`);
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
      .eq('id', deliveryData.driver_id);

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
