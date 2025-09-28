// @ts-nocheck
// Pair Driver Edge Function (scaffold)
// In a full implementation, query driver locations (PostGIS) and create driver_offers.

import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

interface PairRequest {
  deliveryId: string;
}

serve(async (req) => {
  try {
    if (req.method !== "POST") return new Response("Only POST", { status: 405 });

    const body = (await req.json()) as PairRequest;
    if (!body?.deliveryId) return new Response("Missing deliveryId", { status: 400 });

    const SUPABASE_URL = Deno.env.get("SUPABASE_URL");
    const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY");
    if (!SUPABASE_URL || !SUPABASE_ANON_KEY) return new Response("Missing Supabase env", { status: 500 });

    const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
      global: { headers: { Authorization: req.headers.get("Authorization") ?? "" } },
    });

    // Verify auth
    const { data: authData, error: authErr } = await supabase.auth.getUser();
    if (authErr || !authData?.user) return new Response("Unauthorized", { status: 401 });

    // For now, just tag the delivery as 'searching' if not already
    const { data: updated, error: updErr } = await supabase
      .from('deliveries')
      .update({ status: 'searching' })
      .eq('id', body.deliveryId)
      .select()
      .single();

    if (updErr) {
      console.error(updErr);
      return new Response("Failed to update delivery", { status: 400 });
    }

    // TODO: Insert driver_offers based on proximity & availability
    return new Response(JSON.stringify({ ok: true, delivery: updated }), {
      headers: { 'content-type': 'application/json' },
      status: 200,
    });
  } catch (e) {
    console.error(e);
    return new Response("Internal error", { status: 500 });
  }
});
