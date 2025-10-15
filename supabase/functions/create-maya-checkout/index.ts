// Supabase Edge Function: create-maya-checkout
// Purpose: Create Maya checkout session with auth+capture flow
// Date: October 15, 2025

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

interface CheckoutRequest {
  deliveryId: string
  amount: number // Delivery fee only (processing fee calculated here)
  paymentMethod: 'creditCard' | 'mayaWallet'
  customerName: string
  customerEmail?: string
  customerPhone: string
  savedCardToken?: string // Optional: Use saved card from vault
  saveCard?: boolean // Optional: Save card after payment
  metadata?: Record<string, any>
}

interface MayaCheckoutResponse {
  success: boolean
  checkoutId?: string
  checkoutUrl?: string
  expiresAt?: string
  authorizationId?: string
  totalAmount?: number // Delivery fee + processing fee
  processingFee?: number
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
    const MAYA_PUBLIC_KEY = Deno.env.get('MAYA_PUBLIC_KEY')
    const MAYA_ENVIRONMENT = Deno.env.get('MAYA_ENVIRONMENT') || 'sandbox'
    const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!
    const SUPABASE_SERVICE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!

    if (!MAYA_SECRET_KEY || !MAYA_PUBLIC_KEY) {
      throw new Error('Maya API keys not configured')
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

    // Verify user token
    const token = authHeader.replace('Bearer ', '')
    const { data: { user }, error: authError } = await supabase.auth.getUser(token)
    
    if (authError || !user) {
      return new Response(
        JSON.stringify({ error: 'Invalid authorization token' }),
        { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Parse request body
    const body: CheckoutRequest = await req.json()
    const {
      deliveryId,
      amount,
      paymentMethod,
      customerName,
      customerEmail,
      customerPhone,
      savedCardToken,
      saveCard = false,
      metadata = {},
    } = body

    // Validate request
    if (!deliveryId || !amount || !paymentMethod || !customerName || !customerPhone) {
      return new Response(
        JSON.stringify({ error: 'Missing required fields' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Calculate processing fee
    const processingFee = calculateProcessingFee(amount, paymentMethod)
    const totalAmount = amount + processingFee

    console.log(`Creating checkout for delivery ${deliveryId}:`, {
      deliveryFee: amount,
      processingFee,
      totalAmount,
      paymentMethod,
      usingSavedCard: !!savedCardToken,
    })

    // Prepare Maya API base URL
    const mayaBaseUrl = MAYA_ENVIRONMENT === 'production'
      ? 'https://pg.paymaya.com'
      : 'https://pg-sandbox.paymaya.com'

    // Prepare authorization header for Maya API
    const mayaAuthHeader = 'Basic ' + btoa(`${MAYA_SECRET_KEY}:`)

    // Build checkout request for Maya with Auth+Capture
    const mayaCheckoutRequest = {
      authorizationType: 'NORMAL', // NORMAL = can capture up to authorized amount, 6-day hold
      totalAmount: {
        value: totalAmount,
        currency: 'PHP',
      },
      buyer: {
        firstName: customerName.split(' ')[0] || customerName,
        lastName: customerName.split(' ').slice(1).join(' ') || '-',
        contact: {
          phone: customerPhone,
          email: customerEmail || `${user.id}@swiftdash.app`,
        },
      },
      items: [
        {
          name: 'SwiftDash Delivery Service',
          quantity: 1,
          code: deliveryId,
          description: `Delivery Fee: ₱${amount.toFixed(2)} + Processing Fee: ₱${processingFee.toFixed(2)}`,
          amount: {
            value: amount,
            currency: 'PHP',
          },
        },
        {
          name: 'Payment Processing Fee',
          quantity: 1,
          code: 'PROCESSING_FEE',
          description: `${paymentMethod === 'creditCard' ? '3.5% + ₱15' : '2.5%'} transaction fee`,
          amount: {
            value: processingFee,
            currency: 'PHP',
          },
        },
      ],
      redirectUrl: {
        success: `swiftdash://payment/success?deliveryId=${deliveryId}`,
        failure: `swiftdash://payment/failure?deliveryId=${deliveryId}`,
        cancel: `swiftdash://payment/cancel?deliveryId=${deliveryId}`,
      },
      requestReferenceNumber: `SWIFTDASH_${deliveryId}_${Date.now()}`,
      metadata: {
        deliveryId,
        customerId: user.id,
        paymentMethod,
        deliveryFee: amount,
        processingFee,
        totalAmount,
        saveCard,
        timestamp: new Date().toISOString(),
        ...metadata,
      },
    }

    // Add payment token if using saved card
    if (savedCardToken) {
      mayaCheckoutRequest['paymentTokenId'] = savedCardToken
    }

    console.log('Calling Maya Checkout API...')

    // Call Maya Checkout API
    const mayaResponse = await fetch(`${mayaBaseUrl}/checkout/v1/checkouts`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': mayaAuthHeader,
      },
      body: JSON.stringify(mayaCheckoutRequest),
    })

    const mayaResponseText = await mayaResponse.text()
    console.log('Maya API Response:', mayaResponse.status, mayaResponseText)

    if (!mayaResponse.ok) {
      let errorMessage = 'Failed to create Maya checkout'
      try {
        const errorData = JSON.parse(mayaResponseText)
        errorMessage = errorData.message || errorData.error || errorMessage
      } catch {
        errorMessage = mayaResponseText || errorMessage
      }

      return new Response(
        JSON.stringify({
          success: false,
          error: errorMessage,
          errorCode: 'MAYA_API_ERROR',
        } as MayaCheckoutResponse),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    const mayaData = JSON.parse(mayaResponseText)
    const checkoutId = mayaData.checkoutId
    const checkoutUrl = mayaData.redirectUrl
    const expiresAt = mayaData.expiresAt

    console.log('Maya checkout created:', { checkoutId, checkoutUrl })

    // Update delivery record with authorization info
    const { error: updateError } = await supabase
      .from('deliveries')
      .update({
        maya_checkout_id: checkoutId,
        payment_status: 'pending', // Will become 'authorized' after webhook
        payment_total_amount: totalAmount,
        payment_processing_fee: processingFee,
        payment_metadata: {
          checkoutUrl,
          expiresAt,
          paymentMethod,
          saveCard,
          requestReferenceNumber: mayaCheckoutRequest.requestReferenceNumber,
        },
        updated_at: new Date().toISOString(),
      })
      .eq('id', deliveryId)

    if (updateError) {
      console.error('Failed to update delivery:', updateError)
      // Don't fail the request, checkout is created
    }

    // Return success response
    const response: MayaCheckoutResponse = {
      success: true,
      checkoutId,
      checkoutUrl,
      expiresAt,
      totalAmount,
      processingFee,
    }

    return new Response(
      JSON.stringify(response),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )

  } catch (error) {
    console.error('Error in create-maya-checkout:', error)
    
    return new Response(
      JSON.stringify({
        success: false,
        error: error.message || 'Internal server error',
        errorCode: 'INTERNAL_ERROR',
      } as MayaCheckoutResponse),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }
})

/**
 * Calculate Maya processing fee based on payment method
 * Credit/Debit Cards: 3.5% + ₱15
 * Maya Wallet: 2.5%
 */
function calculateProcessingFee(amount: number, paymentMethod: string): number {
  if (paymentMethod === 'creditCard') {
    return Math.round((amount * 0.035 + 15) * 100) / 100 // 3.5% + ₱15, rounded to 2 decimals
  } else if (paymentMethod === 'mayaWallet') {
    return Math.round((amount * 0.025) * 100) / 100 // 2.5%, rounded to 2 decimals
  }
  return 0
}
