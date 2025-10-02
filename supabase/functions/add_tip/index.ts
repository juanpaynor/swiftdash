import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const supabase = createClient(
  Deno.env.get('SUPABASE_URL') ?? '',
  Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
);

interface TipRequest {
  deliveryId: string;
  tipAmount: number;
  customerId: string;
}

Deno.serve(async (req) => {
  // Set CORS headers
  const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
    'Access-Control-Allow-Methods': 'POST, OPTIONS',
  };

  if (req.method === 'OPTIONS') {
    return new Response(null, { headers: corsHeaders });
  }

  try {
    if (req.method !== 'POST') {
      return new Response(
        JSON.stringify({ error: 'Method not allowed' }),
        { status: 405, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    const { deliveryId, tipAmount, customerId }: TipRequest = await req.json();

    // Validate input
    if (!deliveryId || !tipAmount || !customerId || tipAmount <= 0) {
      return new Response(
        JSON.stringify({ error: 'Missing or invalid required fields' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    // Verify delivery belongs to customer and is delivered
    const { data: delivery, error: deliveryError } = await supabase
      .from('deliveries')
      .select('driver_id, status, total_price')
      .eq('id', deliveryId)
      .eq('customer_id', customerId)
      .eq('status', 'delivered')
      .single();

    if (deliveryError || !delivery) {
      return new Response(
        JSON.stringify({ error: 'Invalid delivery or delivery not found' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    // Check if tip already added for this delivery
    const { data: existingEarnings } = await supabase
      .from('driver_earnings')
      .select('tips')
      .eq('delivery_id', deliveryId)
      .single();

    if (existingEarnings && existingEarnings.tips > 0) {
      return new Response(
        JSON.stringify({ error: 'Tip already added for this delivery' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    // Add tip to driver earnings
    const { error: updateError } = await supabase
      .from('driver_earnings')
      .update({
        tips: tipAmount,
        total_earnings: supabase.sql`total_earnings + ${tipAmount}`,
        updated_at: new Date().toISOString()
      })
      .eq('delivery_id', deliveryId);

    if (updateError) {
      console.error('Error updating driver earnings:', updateError);
      throw new Error('Failed to update driver earnings');
    }

    // Get driver info for notification
    const { data: driverProfile } = await supabase
      .from('driver_profiles')
      .select('name, user_id')
      .eq('id', delivery.driver_id)
      .single();

    // Send notification to driver
    await supabase
      .from('notifications')
      .insert({
        driver_id: delivery.driver_id,
        customer_id: customerId,
        message: `You received a ₱${tipAmount.toFixed(2)} tip! Thank you for the excellent service.`,
        type: 'tip_received',
        data: {
          delivery_id: deliveryId,
          tip_amount: tipAmount,
          total_delivery_value: delivery.total_price + tipAmount
        }
      });

    // Log the tip event
    await supabase
      .from('delivery_events')
      .insert({
        delivery_id: deliveryId,
        customer_id: customerId,
        driver_id: delivery.driver_id,
        event_type: 'tip_added',
        event_data: {
          tip_amount: tipAmount,
          timestamp: new Date().toISOString()
        },
        processed: true
      });

    console.log(`Tip of ₱${tipAmount} added to delivery ${deliveryId}`);

    return new Response(
      JSON.stringify({ 
        success: true, 
        message: `Tip of ₱${tipAmount.toFixed(2)} added successfully`,
        driverName: driverProfile?.name || 'Driver'
      }),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );

  } catch (error) {
    console.error('Add tip error:', error);
    return new Response(
      JSON.stringify({ 
        error: 'Internal server error',
        details: error.message 
      }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  }
});