// Supabase Edge Function: capture-maya-payment
// Purpose: Capture authorized payment when driver accepts delivery
// Date: October 15, 2025

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

interface CaptureRequest {
  deliveryId: string
  amount?: number // Optional: partial capture (default: full amount)
}

interface CaptureResponse {
  success: boolean
  paymentId?: string
  capturedAmount?: number
  capturedAt?: string
  error?: string
  errorCode?: string
}

serve(async (req) => {
  // Handle CORS preflight
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    // Get environment variables
    const MAYA_SECRET_KEY = Deno.env.get('MAYA_SECRET_KEY')
    const MAYA_ENVIRONMENT = Deno.env.get('MAYA_ENVIRONMENT') || 'sandbox'
    const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!
    const SUPABASE_SERVICE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!

    if (!MAYA_SECRET_KEY) {
      throw new Error('Maya API key not configured')
    }

    // Get authorization header
    const authHeader = req.headers.get('Authorization')
    if (!authHeader) {
      return new Response(
        JSON.stringify({ error: 'Missing authorization header' }),
        { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Create Supabase client
    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY)

    // Verify user token (allow service role for automated captures)
    const token = authHeader.replace('Bearer ', '')
    const isServiceRole = token === SUPABASE_SERVICE_KEY

    if (!isServiceRole) {
      const { data: { user }, error: authError } = await supabase.auth.getUser(token)
      if (authError || !user) {
        return new Response(
          JSON.stringify({ error: 'Invalid authorization token' }),
          { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        )
      }
    }

    // Parse request body
    const body: CaptureRequest = await req.json()
    const { deliveryId, amount } = body

    if (!deliveryId) {
      return new Response(
        JSON.stringify({ error: 'Missing delivery ID' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Get delivery record
    const { data: delivery, error: fetchError } = await supabase
      .from('deliveries')
      .select('*')
      .eq('id', deliveryId)
      .single()

    if (fetchError || !delivery) {
      return new Response(
        JSON.stringify({ error: 'Delivery not found' }),
        { status: 404, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Validate payment can be captured
    if (!delivery.payment_authorization_id) {
      return new Response(
        JSON.stringify({ 
          success: false,
          error: 'No payment authorization found for this delivery',
          errorCode: 'NO_AUTHORIZATION',
        }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    if (delivery.payment_captured_at) {
      return new Response(
        JSON.stringify({ 
          success: false,
          error: 'Payment already captured',
          errorCode: 'ALREADY_CAPTURED',
        }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    if (delivery.payment_void_at) {
      return new Response(
        JSON.stringify({ 
          success: false,
          error: 'Payment authorization was voided',
          errorCode: 'AUTHORIZATION_VOIDED',
        }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    if (delivery.payment_status !== 'authorized') {
      return new Response(
        JSON.stringify({ 
          success: false,
          error: `Cannot capture payment in status: ${delivery.payment_status}`,
          errorCode: 'INVALID_STATUS',
        }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    console.log(`Capturing payment for delivery ${deliveryId}:`, {
      authorizationId: delivery.payment_authorization_id,
      authorizedAmount: delivery.payment_total_amount,
      captureAmount: amount || delivery.payment_total_amount,
    })

    // Prepare Maya API base URL
    const mayaBaseUrl = MAYA_ENVIRONMENT === 'production'
      ? 'https://pg.paymaya.com'
      : 'https://pg-sandbox.paymaya.com'

    // Prepare authorization header for Maya API
    const mayaAuthHeader = 'Basic ' + btoa(`${MAYA_SECRET_KEY}:`)

    // Build capture request for Maya
    // Note: paymentId is the checkoutId from Maya Checkout API
    const paymentId = delivery.maya_checkout_id || delivery.payment_authorization_id
    
    if (!paymentId) {
      return new Response(
        JSON.stringify({ 
          success: false,
          error: 'No payment ID found for this delivery',
          errorCode: 'NO_PAYMENT_ID',
        } as CaptureResponse),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    const captureAmount = amount || delivery.payment_total_amount
    const mayCaptureRequest = {
      requestReferenceNumber: `CAPTURE_${deliveryId}_${Date.now()}`,
      ...(amount && { totalAmount: { value: amount, currency: 'PHP' } }), // Optional partial capture
    }

    // Call Maya Capture API (correct endpoint from Maya guide)
    const mayaResponse = await fetch(
      `${mayaBaseUrl}/payments/v1/payments/${paymentId}/capture`,
      {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': mayaAuthHeader,
        },
        body: JSON.stringify(mayCaptureRequest),
      }
    )

    const mayaResponseText = await mayaResponse.text()
    console.log('Maya Capture API Response:', mayaResponse.status, mayaResponseText)

    if (!mayaResponse.ok) {
      let errorMessage = 'Failed to capture payment'
      let errorCode = 'MAYA_CAPTURE_ERROR'

      try {
        const errorData = JSON.parse(mayaResponseText)
        errorMessage = errorData.message || errorData.error || errorMessage
        errorCode = errorData.code || errorCode
      } catch {
        errorMessage = mayaResponseText || errorMessage
      }

      // Log failed capture
      await supabase
        .from('deliveries')
        .update({
          payment_error_message: errorMessage,
          payment_metadata: {
            ...delivery.payment_metadata,
            captureError: errorMessage,
            captureErrorCode: errorCode,
            captureErrorTimestamp: new Date().toISOString(),
          },
          updated_at: new Date().toISOString(),
        })
        .eq('id', deliveryId)

      return new Response(
        JSON.stringify({
          success: false,
          error: errorMessage,
          errorCode,
        } as CaptureResponse),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    const mayaData = JSON.parse(mayaResponseText)
    const paymentId = mayaData.id
    const capturedAt = new Date().toISOString()

    console.log('Payment captured successfully:', { paymentId, deliveryId })

    // Update delivery record
    const { error: updateError } = await supabase
      .from('deliveries')
      .update({
        maya_payment_id: paymentId,
        payment_captured_at: capturedAt,
        payment_status: 'paid',
        payment_auto_void_at: null, // Clear auto-void
        payment_processed_at: capturedAt,
        payment_metadata: {
          ...delivery.payment_metadata,
          captureResponse: mayaData,
          capturedAt,
          capturedAmount: captureAmount,
        },
        updated_at: capturedAt,
      })
      .eq('id', deliveryId)

    if (updateError) {
      console.error('Failed to update delivery after capture:', updateError)
      // Payment is captured but DB update failed - log for manual intervention
    }

    // Return success response
    const response: CaptureResponse = {
      success: true,
      paymentId,
      capturedAmount: captureAmount,
      capturedAt,
    }

    return new Response(
      JSON.stringify(response),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )

  } catch (error) {
    console.error('Error in capture-maya-payment:', error)
    
    return new Response(
      JSON.stringify({
        success: false,
        error: error.message || 'Internal server error',
        errorCode: 'INTERNAL_ERROR',
      } as CaptureResponse),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }
})
