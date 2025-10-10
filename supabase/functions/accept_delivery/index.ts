// Accept Delivery Offer Edge Function
// Called by driver app when driver accepts a delivery offer

import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

interface AcceptRequest {
  deliveryId: string;
  driverId: string;
  accept: boolean; // true = accept, false = decline
}

serve(async (req: Request) => {
  try {
    if (req.method !== "POST") return new Response("Only POST", { status: 405 });

    const body = (await req.json()) as AcceptRequest;
    if (!body?.deliveryId || !body?.driverId) {
      return new Response("Missing deliveryId or driverId", { status: 400 });
    }

    const SUPABASE_URL = (globalThis as any).Deno?.env?.get("SUPABASE_URL");
    const SUPABASE_ANON_KEY = (globalThis as any).Deno?.env?.get("SUPABASE_ANON_KEY");
    if (!SUPABASE_URL || !SUPABASE_ANON_KEY) {
      return new Response("Missing Supabase env", { status: 500 });
    }

    const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
      global: { headers: { Authorization: req.headers.get("Authorization") ?? "" } },
    });

    // Verify auth
    const { data: authData, error: authErr } = await supabase.auth.getUser();
    if (authErr || !authData?.user) {
      return new Response("Unauthorized", { status: 401 });
    }

    console.log(`📱 Driver ${body.driverId} ${body.accept ? 'accepting' : 'declining'} delivery ${body.deliveryId}`);

    // Check if delivery is still in offered state
    const { data: delivery, error: deliveryErr } = await supabase
      .from('deliveries')
      .select('status, driver_id')
      .eq('id', body.deliveryId)
      .single();

    if (deliveryErr || !delivery) {
      return new Response("Delivery not found", { status: 404 });
    }

    if (delivery.status !== 'driver_offered' || delivery.driver_id !== body.driverId) {
      return new Response(JSON.stringify({
        ok: false,
        message: "Delivery is no longer available or not offered to this driver"
      }), {
        headers: { 'content-type': 'application/json' },
        status: 400,
      });
    }

    if (body.accept) {
      // Driver accepts - update delivery status and set driver as busy
      const { error: updateErr } = await supabase
        .from('deliveries')
        .update({
          status: 'driver_assigned',
          updated_at: new Date().toISOString()
        })
        .eq('id', body.deliveryId);

      if (updateErr) {
        console.error('Error accepting delivery:', updateErr);
        return new Response("Failed to accept delivery", { status: 500 });
      }

      // Set driver as busy
      await supabase
        .from('driver_profiles')
        .update({ is_available: false })
        .eq('id', body.driverId);

      console.log(`✅ Driver ${body.driverId} accepted delivery ${body.deliveryId}`);

      return new Response(JSON.stringify({
        ok: true,
        message: "Delivery accepted successfully",
        delivery_id: body.deliveryId,
        status: 'driver_assigned'
      }), {
        headers: { 'content-type': 'application/json' },
        status: 200,
      });

    } else {
      // Driver declines - reset delivery to pending and find next driver
      const { error: updateErr } = await supabase
        .from('deliveries')
        .update({
          status: 'pending',
          driver_id: null,
          updated_at: new Date().toISOString()
        })
        .eq('id', body.deliveryId);

      if (updateErr) {
        console.error('Error declining delivery:', updateErr);
        return new Response("Failed to decline delivery", { status: 500 });
      }

      console.log(`❌ Driver ${body.driverId} declined delivery ${body.deliveryId}`);

      // TODO: Could automatically offer to next closest driver here
      
      return new Response(JSON.stringify({
        ok: true,
        message: "Delivery declined",
        delivery_id: body.deliveryId,
        status: 'pending'
      }), {
        headers: { 'content-type': 'application/json' },
        status: 200,
      });
    }

  } catch (e) {
    console.error('Accept delivery error:', e);
    return new Response("Internal error", { status: 500 });
  }
});