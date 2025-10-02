// @ts-nocheck
// Pricing quote Edge Function
// Computes distance (Google Directions API) and price using vehicle_types from DB.
// Includes 12% VAT as required in Philippines

import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

type LatLng = { lat: number; lng: number };

interface QuoteRequest {
  pickup: LatLng;
  dropoff: LatLng;
  vehicleTypeId: string;
  weightKg?: number;
  surge?: number; // optional multiplier e.g., 1.2
}

interface QuoteResponse {
  distanceKm: number;
  base: number;
  perKm: number;
  subtotal: number;
  vat: number;
  vatRate: number;
  surgeMultiplier: number;
  total: number;
  currency: string;
  quoteId: string;
  vehicleTypeId: string;
  expiresAt: string;
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

async function getMapboxDirectionsDistance(pickup: LatLng, dropoff: LatLng): Promise<number> {
  const mapboxToken = Deno.env.get("MAPBOX_ACCESS_TOKEN");
  if (!mapboxToken) {
    console.log("No Mapbox access token, falling back to Haversine distance");
    return haversineKm(pickup, dropoff);
  }

  try {
    const url = `https://api.mapbox.com/directions/v5/mapbox/driving/${pickup.lng},${pickup.lat};${dropoff.lng},${dropoff.lat}?access_token=${mapboxToken}&geometries=geojson`;
    
    const response = await fetch(url);
    const data = await response.json();
    
    if (data.routes && data.routes.length > 0) {
      const distanceMeters = data.routes[0].distance;
      const distanceKm = distanceMeters / 1000;
      console.log(`Mapbox Directions distance: ${distanceKm} km`);
      return distanceKm;
    } else {
      console.log(`Mapbox Directions API error, falling back to Haversine`);
      return haversineKm(pickup, dropoff);
    }
  } catch (error) {
    console.error("Error calling Mapbox Directions API:", error);
    return haversineKm(pickup, dropoff);
  }
}

serve(async (req) => {
  try {
    if (req.method !== "POST") {
      return new Response("Only POST is allowed", { status: 405 });
    }

    const body = (await req.json()) as QuoteRequest;
    if (!body?.pickup || !body?.dropoff || !body?.vehicleTypeId) {
      return new Response("Missing required fields", { status: 400 });
    }

    const SUPABASE_URL = Deno.env.get("SUPABASE_URL");
    const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY");
    if (!SUPABASE_URL || !SUPABASE_ANON_KEY) {
      return new Response("Missing Supabase env", { status: 500 });
    }

    const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
      global: { headers: { Authorization: req.headers.get("Authorization") ?? "" } },
    });

    // Fetch pricing from DB to avoid client tampering
    const { data: vt, error: vtErr } = await supabase
      .from("vehicle_types")
      .select("id, base_price, price_per_km, is_active")
      .eq("id", body.vehicleTypeId)
      .maybeSingle();

    if (vtErr) {
      console.error(vtErr);
      return new Response("Failed to load vehicle pricing", { status: 500 });
    }
    if (!vt || vt.is_active === false) {
      return new Response("Vehicle type unavailable", { status: 400 });
    }

    // Get accurate distance using Mapbox Directions API
    const distanceRaw = await getMapboxDirectionsDistance(body.pickup, body.dropoff);
    const distanceKm = Math.max(0, Math.round(distanceRaw * 10) / 10);

    const base = Number(vt.base_price) || 0;
    const perKm = Number(vt.price_per_km) || 0;
    const subtotal = base + perKm * distanceKm;
    
    // Apply surge pricing if provided
    const surge = body.surge && body.surge > 0 ? body.surge : 1;
    const afterSurge = subtotal * surge;
    
    // Add 12% VAT (Philippine requirement)
    const vatRate = 0.12;
    const vat = afterSurge * vatRate;
    const total = Math.max(1, Math.round((afterSurge + vat) * 100) / 100);

    const resp: QuoteResponse = {
      distanceKm,
      base,
      perKm,
      subtotal: Math.round(subtotal * 100) / 100,
      vat: Math.round(vat * 100) / 100,
      vatRate,
      surgeMultiplier: surge,
      total,
      currency: "PHP", // Philippine Peso
      quoteId: crypto.randomUUID(),
      vehicleTypeId: body.vehicleTypeId,
      expiresAt: new Date(Date.now() + 5 * 60 * 1000).toISOString(),
    };

    return new Response(JSON.stringify(resp), {
      headers: { "content-type": "application/json" },
      status: 200,
    });
  } catch (e) {
    console.error(e);
    return new Response("Internal error", { status: 500 });
  }
});
