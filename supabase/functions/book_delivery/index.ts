// @ts-nocheck
// Book Delivery Edge Function
// Validates the request with user JWT, recomputes price with VAT, and inserts a delivery row.

import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

type LatLng = { lat: number; lng: number };

interface BookRequest {
  vehicleTypeId: string;
  pickup: { address: string; location: LatLng; contactName: string; contactPhone: string; instructions?: string };
  dropoff: { address: string; location: LatLng; contactName: string; contactPhone: string; instructions?: string };
  package?: { description?: string; weightKg?: number; value?: number };
}

function haversineKm(a: LatLng, b: LatLng): number {
  const toRad = (d: number) => (d * Math.PI) / 180;
  const R = 6371; // km
  const dLat = toRad(b.lat - a.lat);
  const dLng = toRad(b.lng - a.lng);
  const lat1 = toRad(a.lat);
  const lat2 = toRad(b.lat);
  const h =
    Math.sin(dLat / 2) ** 2 +
    Math.cos(lat1) * Math.cos(lat2) * Math.sin(dLng / 2) ** 2;
  return 2 * R * Math.asin(Math.sqrt(h));
}

async function getDirectionsDistance(pickup: LatLng, dropoff: LatLng): Promise<number> {
  // Google Maps API removed - using Haversine distance calculation only
  console.log("Using Haversine distance calculation (Google Maps removed)");
  return haversineKm(pickup, dropoff);
}

serve(async (req) => {
  try {
    if (req.method !== "POST") return new Response("Only POST", { status: 405 });

    const body = (await req.json()) as BookRequest;
    if (!body?.vehicleTypeId || !body?.pickup || !body?.dropoff) {
      return new Response("Missing required fields", { status: 400 });
    }

    const SUPABASE_URL = Deno.env.get("SUPABASE_URL");
    const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY");
    if (!SUPABASE_URL || !SUPABASE_ANON_KEY) return new Response("Missing Supabase env", { status: 500 });

    const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
      global: { headers: { Authorization: req.headers.get("Authorization") ?? "" } },
    });

    // Identify user
    const { data: authData, error: authErr } = await supabase.auth.getUser();
    if (authErr || !authData?.user) return new Response("Unauthorized", { status: 401 });
    const userId = authData.user.id;

    // Fetch pricing
    const { data: vt, error: vtErr } = await supabase
      .from("vehicle_types")
      .select("id, base_price, price_per_km, is_active")
      .eq("id", body.vehicleTypeId)
      .maybeSingle();

    if (vtErr) {
      console.error(vtErr);
      return new Response("Failed to load vehicle pricing", { status: 500 });
    }
    if (!vt || vt.is_active === false) return new Response("Vehicle type unavailable", { status: 400 });

    // Get accurate distance using Google Directions API
    const distanceKm = Math.max(0, Math.round((await getDirectionsDistance(body.pickup.location, body.dropoff.location)) * 10) / 10);
    
    const base = Number(vt.base_price) || 0;
    const perKm = Number(vt.price_per_km) || 0;
    const subtotal = base + perKm * distanceKm;
    
    // Add 12% VAT (Philippine requirement)
    const vatRate = 0.12;
    const vat = subtotal * vatRate;
    const total = Math.max(1, Math.round((subtotal + vat) * 100) / 100);

    // Insert delivery (RLS should allow if policies are set for authenticated users)
    const insertPayload: Record<string, unknown> = {
      customer_id: userId,
      vehicle_type_id: body.vehicleTypeId,
      pickup_address: body.pickup.address,
      pickup_latitude: body.pickup.location.lat,
      pickup_longitude: body.pickup.location.lng,
      pickup_contact_name: body.pickup.contactName,
      pickup_contact_phone: body.pickup.contactPhone,
      pickup_instructions: body.pickup.instructions ?? null,
      delivery_address: body.dropoff.address,
      delivery_latitude: body.dropoff.location.lat,
      delivery_longitude: body.dropoff.location.lng,
      delivery_contact_name: body.dropoff.contactName,
      delivery_contact_phone: body.dropoff.contactPhone,
      delivery_instructions: body.dropoff.instructions ?? null,
      package_description: body.package?.description ?? null,
      package_weight: body.package?.weightKg ?? null,
      package_value: body.package?.value ?? null,
      distance_km: distanceKm,
      total_price: total,
    };

    const { data: created, error: insErr } = await supabase
      .from("deliveries")
      .insert(insertPayload)
      .select()
      .single();

    if (insErr) {
      console.error(insErr);
      return new Response("Failed to create delivery", { status: 400 });
    }

    return new Response(JSON.stringify(created), { headers: { "content-type": "application/json" }, status: 200 });
  } catch (e) {
    console.error(e);
    return new Response("Internal error", { status: 500 });
  }
});
