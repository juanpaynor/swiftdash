// Maya Payment Webhook Handler for SwiftDash
import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { corsHeaders } from '../_shared/cors.ts'

interface MayaWebhookPayload {
  id: string
  type: string
  attributes: {
    type: string
    amount: number
    currency: string
    description: string
    status: string
    fee: number
    refunds: any[]
    taxes: any[]
    requestReferenceNumber: string
    metadata: Record<string, any>
    paymentAt: string
    createdAt: string
    updatedAt: string
    checkout?: {
      id: string
      totalAmount: {
        currency: string
        value: string
      }
      buyer?: {
        firstName: string
        lastName: string
        contact: {
          phone: string
          email: string
        }
      }
    }
  }
}

serve(async (req) => {
  // Handle CORS preflight requests
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    console.log('Maya webhook received:', req.method, req.url)

    // Only accept POST requests
    if (req.method !== 'POST') {
      return new Response(
        JSON.stringify({ error: 'Method not allowed' }),
        { 
          status: 405, 
          headers: { ...corsHeaders, 'Content-Type': 'application/json' } 
        }
      )
    }

    // Parse webhook payload
    const payload: MayaWebhookPayload = await req.json()
    console.log('Maya webhook payload:', JSON.stringify(payload, null, 2))

    // Initialize Supabase client
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    const supabase = createClient(supabaseUrl, supabaseServiceKey)

    // Extract payment information
    const {
      id: paymentId,
      type: eventType,
      attributes: {
        status,
        amount,
        currency,
        requestReferenceNumber,
        metadata,
        paymentAt,
        checkout
      }
    } = payload

    console.log(`Processing ${eventType} for payment ${paymentId} with status ${status}`)

    // Extract delivery ID from metadata or reference number
    let deliveryId = metadata?.deliveryId
    if (!deliveryId && requestReferenceNumber) {
      // Extract from reference number format: SWIFTDASH_deliveryId_timestamp
      const parts = requestReferenceNumber.split('_')
      if (parts.length >= 2 && parts[0] === 'SWIFTDASH') {
        deliveryId = parts[1]
      }
    }

    if (!deliveryId) {
      console.error('No delivery ID found in webhook payload')
      return new Response(
        JSON.stringify({ error: 'Delivery ID not found' }),
        { 
          status: 400, 
          headers: { ...corsHeaders, 'Content-Type': 'application/json' } 
        }
      )
    }

    // Map Maya payment status to our payment status
    let paymentStatus = 'pending'
    switch (status.toLowerCase()) {
      case 'payment_success':
      case 'paid':
        paymentStatus = 'paid'
        break
      case 'payment_failed':
      case 'failed':
        paymentStatus = 'failed'
        break
      case 'payment_cancelled':
      case 'cancelled':
        paymentStatus = 'pending'
        break
      default:
        paymentStatus = 'processing'
    }

    // Update delivery with payment information
    const { data: delivery, error: deliveryError } = await supabase
      .from('deliveries')
      .update({
        payment_status: paymentStatus,
        maya_payment_id: paymentId,
        maya_checkout_id: checkout?.id,
        payment_processed_at: paymentAt ? new Date(paymentAt).toISOString() : new Date().toISOString(),
        payment_metadata: {
          ...metadata,
          maya_event_type: eventType,
          maya_amount: amount,
          maya_currency: currency,
          maya_fee: payload.attributes.fee || 0,
          webhook_timestamp: new Date().toISOString()
        },
        updated_at: new Date().toISOString()
      })
      .eq('id', deliveryId)
      .select()
      .single()

    if (deliveryError) {
      console.error('Error updating delivery:', deliveryError)
      return new Response(
        JSON.stringify({ error: 'Failed to update delivery', details: deliveryError }),
        { 
          status: 500, 
          headers: { ...corsHeaders, 'Content-Type': 'application/json' } 
        }
      )
    }

    console.log(`Successfully updated delivery ${deliveryId} with payment status ${paymentStatus}`)

    // Send real-time notification to customer app
    if (paymentStatus === 'paid') {
      // Trigger any additional business logic for successful payments
      console.log(`Payment successful for delivery ${deliveryId} - amount: ${amount} ${currency}`)
      
      // You could trigger driver matching here if payment was required before driver assignment
      // await triggerDriverMatching(deliveryId)
    } else if (paymentStatus === 'failed') {
      console.log(`Payment failed for delivery ${deliveryId}`)
      
      // You might want to notify the customer or cancel the delivery
      // await notifyPaymentFailure(deliveryId)
    }

    // Return success response to Maya
    return new Response(
      JSON.stringify({ 
        success: true, 
        message: 'Webhook processed successfully',
        deliveryId,
        paymentStatus
      }),
      { 
        status: 200, 
        headers: { ...corsHeaders, 'Content-Type': 'application/json' } 
      }
    )

  } catch (error) {
    console.error('Maya webhook error:', error)
    
    return new Response(
      JSON.stringify({ 
        error: 'Internal server error', 
        message: error.message 
      }),
      { 
        status: 500, 
        headers: { ...corsHeaders, 'Content-Type': 'application/json' } 
      }
    )
  }
})

/* Maya Webhook Events:
 * 
 * CHECKOUT_SUCCESS - Checkout completed successfully
 * CHECKOUT_FAILURE - Checkout failed
 * CHECKOUT_DROPOUT - User abandoned checkout
 * PAYMENT_SUCCESS - Payment processed successfully
 * PAYMENT_FAILED - Payment processing failed
 * PAYMENT_EXPIRED - Payment session expired
 * 
 * Webhook URL for Maya dashboard:
 * https://your-project-id.supabase.co/functions/v1/maya-webhook
 */