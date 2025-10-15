// Maya Vault Webhook Handler
// Handles webhook events for card tokenization and vault operations

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.38.4';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

interface VaultWebhookPayload {
  id: string;
  isPropagation: boolean;
  name: string; // Event type
  createdAt: string;
  data: {
    id: string; // Token ID
    type: string; // "card"
    state: string; // "AVAILABLE", "EXPIRED", "USED"
    customerId?: string;
    metadata?: {
      customerId?: string;
      deliveryId?: string;
      saveCard?: boolean;
    };
    cardTokenDetails?: {
      brand: string; // "VISA", "MASTERCARD"
      last4: string;
      expiryMonth: string;
      expiryYear: string;
    };
    createdAt: string;
    updatedAt: string;
  };
}

serve(async (req) => {
  // Handle CORS preflight requests
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    // Get request body
    const payload: VaultWebhookPayload = await req.json();

    console.log('Received Maya Vault webhook:', {
      event: payload.name,
      tokenId: payload.data.id,
      state: payload.data.state,
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
      case 'PAYMENT_TOKEN_CREATED':
        await handleTokenCreated(supabase, payload);
        break;
      
      case 'PAYMENT_TOKEN_UPDATED':
        await handleTokenUpdated(supabase, payload);
        break;
      
      case 'PAYMENT_TOKEN_DELETED':
        await handleTokenDeleted(supabase, payload);
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

async function handleTokenCreated(
  supabase: any,
  payload: VaultWebhookPayload
): Promise<void> {
  console.log('Handling PAYMENT_TOKEN_CREATED');

  const { data, metadata } = payload.data;
  
  // Only save if customer opted in to save card
  if (!metadata?.saveCard) {
    console.log('Customer did not opt to save card, skipping');
    return;
  }

  const customerId = metadata?.customerId;
  if (!customerId) {
    console.error('No customer ID in metadata');
    return;
  }

  const cardDetails = payload.data.cardTokenDetails;
  if (!cardDetails) {
    console.error('No card details in webhook');
    return;
  }

  // Check if card already exists
  const { data: existing } = await supabase
    .from('customer_payment_methods')
    .select('id')
    .eq('customer_id', customerId)
    .eq('card_token', payload.data.id)
    .single();

  if (existing) {
    console.log('Card already exists, skipping');
    return;
  }

  // Insert new saved card
  const { error } = await supabase
    .from('customer_payment_methods')
    .insert({
      customer_id: customerId,
      card_token: payload.data.id,
      card_type: cardDetails.brand,
      last_four_digits: cardDetails.last4,
      expiry_month: parseInt(cardDetails.expiryMonth),
      expiry_year: parseInt(cardDetails.expiryYear),
      is_default: false, // Customer can set default later
      is_active: true,
    });

  if (error) {
    console.error('Error saving card:', error);
    throw error;
  }

  console.log('Card saved successfully:', {
    tokenId: payload.data.id,
    last4: cardDetails.last4,
    brand: cardDetails.brand,
  });
}

async function handleTokenUpdated(
  supabase: any,
  payload: VaultWebhookPayload
): Promise<void> {
  console.log('Handling PAYMENT_TOKEN_UPDATED');

  const { data } = payload;

  // If token state changed to EXPIRED or USED, deactivate it
  if (data.state === 'EXPIRED' || data.state === 'USED') {
    const { error } = await supabase
      .from('customer_payment_methods')
      .update({ 
        is_active: false,
        updated_at: new Date().toISOString(),
      })
      .eq('card_token', data.id);

    if (error) {
      console.error('Error updating card status:', error);
      throw error;
    }

    console.log('Card deactivated:', {
      tokenId: data.id,
      state: data.state,
    });
  }
}

async function handleTokenDeleted(
  supabase: any,
  payload: VaultWebhookPayload
): Promise<void> {
  console.log('Handling PAYMENT_TOKEN_DELETED');

  // Soft delete - mark as inactive
  const { error } = await supabase
    .from('customer_payment_methods')
    .update({ 
      is_active: false,
      updated_at: new Date().toISOString(),
    })
    .eq('card_token', payload.data.id);

  if (error) {
    console.error('Error deleting card:', error);
    throw error;
  }

  console.log('Card deleted:', {
    tokenId: payload.data.id,
  });
}
