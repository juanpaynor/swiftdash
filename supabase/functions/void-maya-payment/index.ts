// Supabase Edge Function: void-maya-payment
// Purpose: Void authorized payment (cancel authorization without charging customer)
// Date: October 15, 2025

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

interface VoidRequest {
  deliveryId: string
  reason?: string
}

interface VoidResponse {
  success: boolean
  voidedAt?: string
  reason?: string
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

    // Verify token (allow service role for automated voids)
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
    const body: VoidRequest = await req.json()
    const { deliveryId, reason = 'Delivery cancelled' } = body

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

    // Validate payment can be voided
    if (!delivery.payment_authorization_id) {
      return new Response(
        JSON.stringify({ 
          success: false,
          error: 'No payment authorization found',
          errorCode: 'NO_AUTHORIZATION',
        }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    if (delivery.payment_captured_at) {
      return new Response(
        JSON.stringify({ 
          success: false,
          error: 'Cannot void captured payment - refund required',
          errorCode: 'ALREADY_CAPTURED',
        }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    if (delivery.payment_void_at) {
      return new Response(
        JSON.stringify({ 
          success: true, // Already voided, return success
          voidedAt: delivery.payment_void_at,
          reason: 'Already voided',
        }),
        { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    if (delivery.payment_status !== 'authorized') {
      return new Response(
        JSON.stringify({ 
          success: false,
          error: `Cannot void payment in status: ${delivery.payment_status}`,
          errorCode: 'INVALID_STATUS',
        }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    console.log(`Voiding payment for delivery ${deliveryId}:`, {
      authorizationId: delivery.payment_authorization_id,
      reason,
    })

    // Prepare Maya API base URL
    const mayaBaseUrl = MAYA_ENVIRONMENT === 'production'
      ? 'https://pg.paymaya.com'
      : 'https://pg-sandbox.paymaya.com'

    // Prepare authorization header for Maya API
    const mayaAuthHeader = 'Basic ' + btoa(`${MAYA_SECRET_KEY}:`)

    // Build void request for Maya
    const mayaVoidRequest = {
      requestReferenceNumber: `VOID_${deliveryId}_${Date.now()}`,
      metadata: {
        deliveryId,
        voidReason: reason,
        originalAmount: delivery.payment_total_amount,
      },
    }

    // Call Maya Void API
    const mayaResponse = await fetch(
      `${mayaBaseUrl}/payments/v1/payment-rrns/${delivery.payment_authorization_id}/void`,
      {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': mayaAuthHeader,
        },
        body: JSON.stringify(mayaVoidRequest),
      }
    )

    const mayaResponseText = await mayaResponse.text()
    console.log('Maya Void API Response:', mayaResponse.status, mayaResponseText)

    if (!mayaResponse.ok) {
      let errorMessage = 'Failed to void payment'
      let errorCode = 'MAYA_VOID_ERROR'

      try {
        const errorData = JSON.parse(mayaResponseText)
        errorMessage = errorData.message || errorData.error || errorMessage
        errorCode = errorData.code || errorCode
      } catch {
        errorMessage = mayaResponseText || errorMessage
      }

      // If authorization expired or already voided, consider it success
      if (errorCode === 'AUTHORIZATION_EXPIRED' || errorCode === 'ALREADY_VOIDED') {
        console.log('Authorization already expired/voided, updating DB')
      } else {
        // Log failed void
        await supabase
          .from('deliveries')
          .update({
            payment_error_message: `Void failed: ${errorMessage}`,
            payment_metadata: {
              ...delivery.payment_metadata,
              voidError: errorMessage,
              voidErrorCode: errorCode,
              voidErrorTimestamp: new Date().toISOString(),
            },
            updated_at: new Date().toISOString(),
          })
          .eq('id', deliveryId)

        return new Response(
          JSON.stringify({
            success: false,
            error: errorMessage,
            errorCode,
          } as VoidResponse),
          { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        )
      }
    }

    const voidedAt = new Date().toISOString()

    console.log('Payment voided successfully:', deliveryId)

    // Update delivery record
    const { error: updateError } = await supabase
      .from('deliveries')
      .update({
        payment_void_at: voidedAt,
        payment_status: 'voided',
        payment_auto_void_at: null, // Clear auto-void
        payment_error_message: reason,
        payment_metadata: {
          ...delivery.payment_metadata,
          voidedAt,
          voidReason: reason,
        },
        updated_at: voidedAt,
      })
      .eq('id', deliveryId)

    if (updateError) {
      console.error('Failed to update delivery after void:', updateError)
      // Payment is voided but DB update failed - log for manual intervention
    }

    // Return success response
    const response: VoidResponse = {
      success: true,
      voidedAt,
      reason,
    }

    return new Response(
      JSON.stringify(response),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )

  } catch (error) {
    console.error('Error in void-maya-payment:', error)
    
    return new Response(
      JSON.stringify({
        success: false,
        error: error.message || 'Internal server error',
        errorCode: 'INTERNAL_ERROR',
      } as VoidResponse),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }
})
