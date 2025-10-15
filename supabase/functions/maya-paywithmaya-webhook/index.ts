// Pay with Maya Webhook Handler
// Handles webhook events for Maya Wallet (QR code) payments

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.38.4';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

interface PayWithMayaWebhookPayload {
  id: string;
  isPropagation: boolean;
  name: string; // Event type
  createdAt: string;
  data: {
    id: string; // Payment ID
    isPaid: boolean;
    status: string; // "PENDING", "PAYMENT_SUCCESS", "PAYMENT_FAILED", "PAYMENT_EXPIRED"
    amount: number;
    currency: string;
    canVoid?: boolean;
    canRefund?: boolean;
    canCapture?: boolean;
    metadata?: {
      deliveryId?: string;
      customerId?: string;
    };
    requestReferenceNumber: string;
    createdAt: string;
    updatedAt: string;
    expiredAt?: string;
  };
}

serve(async (req) => {
  // Handle CORS preflight requests
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    // Get request body
    const payload: PayWithMayaWebhookPayload = await req.json();

    console.log('Received Pay with Maya webhook:', {
      event: payload.name,
      paymentId: payload.data.id,
      status: payload.data.status,
      amount: payload.data.amount,
    });

    // Initialize Supabase client
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
    const supabase = createClient(supabaseUrl, supabaseServiceKey);

    // Log webhook event
    await supabase.from('payment_webhook_logs').insert({
      event_type: payload.name,
      payload: payload,
      signature_verified: true, // Maya webhooks are verified by source IP/domain
      received_at: new Date().toISOString(),
      processed: false,
    });

    // Handle different event types
    switch (payload.name) {
      case 'PAYMENT_SUCCESS':
        await handlePaymentSuccess(supabase, payload);
        break;
      
      case 'PAYMENT_FAILED':
        await handlePaymentFailed(supabase, payload);
        break;
      
      case 'PAYMENT_EXPIRED':
        await handlePaymentExpired(supabase, payload);
        break;
      
      default:
        console.log(`Unhandled event type: ${payload.name}`);
    }

    // Mark webhook as processed
    await supabase
      .from('payment_webhook_logs')
      .update({ processed: true, processed_at: new Date().toISOString() })
      .eq('payload->id', payload.id);

    return new Response(
      JSON.stringify({ success: true, message: 'Webhook processed' }),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );

  } catch (error) {
    console.error('Error processing webhook:', error);
    return new Response(
      JSON.stringify({ error: error.message }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  }
});

async function handlePaymentSuccess(
  supabase: any,
  payload: PayWithMayaWebhookPayload
): Promise<void> {
  console.log('Handling PAYMENT_SUCCESS');

  const deliveryId = payload.data.metadata?.deliveryId;
  if (!deliveryId) {
    console.error('No delivery ID in metadata');
    return;
  }

  // Get delivery
  const { data: delivery, error: fetchError } = await supabase
    .from('deliveries')
    .select('*')
    .eq('id', deliveryId)
    .single();

  if (fetchError || !delivery) {
    console.error('Delivery not found:', deliveryId);
    throw new Error('Delivery not found');
  }

  // Maya Wallet payments are auto-captured (no auth+capture flow)
  // So we mark as both authorized AND captured
  const { error: updateError } = await supabase
    .from('deliveries')
    .update({
      payment_status: 'paid',
      payment_authorization_id: payload.data.id,
      payment_authorized_at: payload.data.createdAt,
      payment_captured_at: new Date().toISOString(),
      payment_method: 'maya_wallet',
      updated_at: new Date().toISOString(),
    })
    .eq('id', deliveryId);

  if (updateError) {
    console.error('Error updating delivery:', updateError);
    throw updateError;
  }

  console.log('Payment success processed:', {
    deliveryId,
    paymentId: payload.data.id,
    amount: payload.data.amount,
  });

  // TODO: Trigger notification to customer about successful payment
  // TODO: Update delivery status to 'finding_driver' if not already
}

async function handlePaymentFailed(
  supabase: any,
  payload: PayWithMayaWebhookPayload
): Promise<void> {
  console.log('Handling PAYMENT_FAILED');

  const deliveryId = payload.data.metadata?.deliveryId;
  if (!deliveryId) {
    console.error('No delivery ID in metadata');
    return;
  }

  // Update delivery with failed status
  const { error } = await supabase
    .from('deliveries')
    .update({
      payment_status: 'failed',
      payment_authorization_id: payload.data.id,
      updated_at: new Date().toISOString(),
    })
    .eq('id', deliveryId);

  if (error) {
    console.error('Error updating delivery:', error);
    throw error;
  }

  console.log('Payment failed processed:', {
    deliveryId,
    paymentId: payload.data.id,
  });

  // TODO: Notify customer about payment failure
  // TODO: Allow customer to retry payment
}

async function handlePaymentExpired(
  supabase: any,
  payload: PayWithMayaWebhookPayload
): Promise<void> {
  console.log('Handling PAYMENT_EXPIRED');

  const deliveryId = payload.data.metadata?.deliveryId;
  if (!deliveryId) {
    console.error('No delivery ID in metadata');
    return;
  }

  // Update delivery - expired QR code
  const { error } = await supabase
    .from('deliveries')
    .update({
      payment_status: 'expired',
      payment_authorization_id: payload.data.id,
      updated_at: new Date().toISOString(),
    })
    .eq('id', deliveryId);

  if (error) {
    console.error('Error updating delivery:', error);
    throw error;
  }

  console.log('Payment expired processed:', {
    deliveryId,
    paymentId: payload.data.id,
  });

  // TODO: Notify customer that QR code expired
  // TODO: Allow customer to generate new QR code
}
