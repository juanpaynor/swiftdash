// ============================================================================
// MULTI-STOP DELIVERY BOOKING EDGE FUNCTION
// Handles creation of deliveries with unlimited stops
// Includes: pricing calculation, route optimization, validation
// ============================================================================

import { serve } from 'https://deno.land/std@0.177.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.39.0'

// Price configuration is now fetched from vehicle_types table
// No hardcoded pricing - everything comes from database

interface DeliveryStop {
  stopNumber: number
  stopType: 'pickup' | 'dropoff'
  address: string
  latitude: number
  longitude: number
  houseNumber?: string
  street?: string
  barangay?: string
  city?: string
  province?: string
  recipientName: string
  recipientPhone: string
  deliveryNotes?: string
  packageDescription?: string
  packageWeight?: number
}

interface BookMultiStopRequest {
  vehicleTypeId: string
  
  // Pickup location
  pickup: {
    address: string
    location: { lat: number; lng: number }
    contactName: string
    contactPhone: string
    instructions?: string
  }
  
  // Multiple dropoff stops (unlimited)
  dropoffStops: Array<{
    address: string
    location: { lat: number; lng: number }
    contactName: string
    contactPhone: string
    instructions?: string
    packageDescription?: string
    packageWeight?: number
  }>
  
  // Package details
  package?: {
    description?: string
    weightKg?: number
    value?: number
  }
  
  // Scheduling
  isScheduled?: boolean
  scheduledPickupTime?: string
  
  // Payment information
  payment?: {
    paymentBy: string
    paymentMethod: string
    paymentStatus: string
    mayaCheckoutId?: string
    mayaPaymentId?: string
    paymentReference?: string
    paymentMetadata?: any
  }
}

// Calculate distance between two coordinates using Haversine formula
function calculateDistance(
  lat1: number,
  lon1: number,
  lat2: number,
  lon2: number
): number {
  const R = 6371 // Radius of Earth in kilometers
  const dLat = (lat2 - lat1) * (Math.PI / 180)
  const dLon = (lon2 - lon1) * (Math.PI / 180)
  const a =
    Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos(lat1 * (Math.PI / 180)) *
      Math.cos(lat2 * (Math.PI / 180)) *
      Math.sin(dLon / 2) *
      Math.sin(dLon / 2)
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a))
  return R * c
}

// Calculate total route distance (pickup → stop1 → stop2 → ... → stopN)
function calculateTotalRouteDistance(
  pickupLat: number,
  pickupLng: number,
  stops: Array<{ latitude: number; longitude: number }>
): { totalKm: number; distances: number[] } {
  const distances: number[] = []
  let currentLat = pickupLat
  let currentLng = pickupLng
  let totalKm = 0

  for (const stop of stops) {
    const distance = calculateDistance(
      currentLat,
      currentLng,
      stop.latitude,
      stop.longitude
    )
    distances.push(distance)
    totalKm += distance
    currentLat = stop.latitude
    currentLng = stop.longitude
  }

  return { totalKm, distances }
}

// Calculate pricing for multi-stop delivery using database values
async function calculateMultiStopPrice(
  supabaseClient: any,
  vehicleTypeId: string,
  totalKm: number,
  stopCount: number
): Promise<{ totalPrice: number; basePrice: number; distanceCost: number; multiStopFee: number; additionalStopCharge: number }> {
  // Fetch pricing from vehicle_types table
  const { data: vehicleType, error } = await supabaseClient
    .from('vehicle_types')
    .select('base_price, price_per_km, additional_stop_charge')
    .eq('id', vehicleTypeId)
    .single()
  
  if (error || !vehicleType) {
    throw new Error('Failed to fetch vehicle type pricing')
  }
  
  const basePrice = vehicleType.base_price
  const pricePerKm = vehicleType.price_per_km
  const additionalStopCharge = vehicleType.additional_stop_charge || 0
  
  // Base price + distance cost + per-stop fee
  const distanceCost = totalKm * pricePerKm
  const multiStopFee = (stopCount - 1) * additionalStopCharge // First stop is included
  const totalPrice = basePrice + distanceCost + multiStopFee
  
  return { totalPrice, basePrice, distanceCost, multiStopFee, additionalStopCharge }
}

serve(async (req) => {
  try {
    // CORS headers
    if (req.method === 'OPTIONS') {
      return new Response('ok', {
        headers: {
          'Access-Control-Allow-Origin': '*',
          'Access-Control-Allow-Methods': 'POST, OPTIONS',
          'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
        },
      })
    }

    // Initialize Supabase client with service role for bypassing RLS
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
      {
        auth: {
          autoRefreshToken: false,
          persistSession: false,
        },
      }
    )

    // Get user from JWT
    const authHeader = req.headers.get('Authorization')
    if (!authHeader) {
      return new Response(
        JSON.stringify({ error: 'Missing authorization header' }),
        { status: 401, headers: { 'Content-Type': 'application/json' } }
      )
    }

    const token = authHeader.replace('Bearer ', '')
    const { data: userData, error: userError } = await supabaseClient.auth.getUser(token)
    
    if (userError || !userData.user) {
      return new Response(
        JSON.stringify({ error: 'Invalid authorization token' }),
        { status: 401, headers: { 'Content-Type': 'application/json' } }
      )
    }

    const userId = userData.user.id

    // Parse request body
    const body: BookMultiStopRequest = await req.json()

    // Validation
    if (!body.vehicleTypeId) {
      return new Response(
        JSON.stringify({ error: 'vehicleTypeId is required' }),
        { status: 400, headers: { 'Content-Type': 'application/json' } }
      )
    }

    if (!body.dropoffStops || body.dropoffStops.length === 0) {
      return new Response(
        JSON.stringify({ error: 'At least one dropoff stop is required' }),
        { status: 400, headers: { 'Content-Type': 'application/json' } }
      )
    }

    // Fetch vehicle type
    const { data: vehicleType, error: vehicleError } = await supabaseClient
      .from('vehicle_types')
      .select('*')
      .eq('id', body.vehicleTypeId)
      .single()

    if (vehicleError || !vehicleType) {
      return new Response(
        JSON.stringify({ error: 'Invalid vehicle type' }),
        { status: 400, headers: { 'Content-Type': 'application/json' } }
      )
    }

    // Calculate route distance
    const stopLocations = body.dropoffStops.map(stop => ({
      latitude: stop.location.lat,
      longitude: stop.location.lng,
    }))

    const { totalKm, distances } = calculateTotalRouteDistance(
      body.pickup.location.lat,
      body.pickup.location.lng,
      stopLocations
    )

    // Calculate pricing from database
    const totalStops = body.dropoffStops.length
    const pricing = await calculateMultiStopPrice(supabaseClient, body.vehicleTypeId, totalKm, totalStops)

    console.log(`Multi-stop delivery: ${totalStops} stops, ${totalKm.toFixed(2)}km, ₱${pricing.totalPrice.toFixed(2)}`)

    // Create delivery record
    const deliveryData: any = {
      customer_id: userId,
      vehicle_type_id: body.vehicleTypeId,
      
      // Pickup information
      pickup_address: body.pickup.address,
      pickup_latitude: body.pickup.location.lat,
      pickup_longitude: body.pickup.location.lng,
      pickup_contact_name: body.pickup.contactName,
      pickup_contact_phone: body.pickup.contactPhone,
      pickup_instructions: body.pickup.instructions || null,
      
      // Use first dropoff as main delivery address (for backward compatibility)
      delivery_address: body.dropoffStops[0].address,
      delivery_latitude: body.dropoffStops[0].location.lat,
      delivery_longitude: body.dropoffStops[0].location.lng,
      delivery_contact_name: body.dropoffStops[0].contactName,
      delivery_contact_phone: body.dropoffStops[0].contactPhone,
      delivery_instructions: body.dropoffStops[0].instructions || null,
      
      // Package information
      package_description: body.package?.description || 'Multi-stop delivery',
      package_weight: body.package?.weightKg || null,
      package_value: body.package?.value || null,
      
      // Pricing and distance
      distance_km: totalKm,
      total_price: pricing.totalPrice,
      
      // Multi-stop flags
      is_multi_stop: true,
      total_stops: totalStops,
      current_stop_index: 0,
      
      // Scheduling
      is_scheduled: body.isScheduled || false,
      scheduled_pickup_time: body.scheduledPickupTime || null,
      
      // Status
      status: 'pending',
      
      // Payment information
      payment_by: body.payment?.paymentBy || null,
      payment_method: body.payment?.paymentMethod || null,
      payment_status: body.payment?.paymentStatus || 'pending',
      maya_checkout_id: body.payment?.mayaCheckoutId || null,
      payment_reference: body.payment?.paymentReference || null,
    }

    // Insert delivery
    const { data: delivery, error: deliveryError } = await supabaseClient
      .from('deliveries')
      .insert(deliveryData)
      .select()
      .single()

    if (deliveryError) {
      console.error('Error creating delivery:', deliveryError)
      return new Response(
        JSON.stringify({ error: 'Failed to create delivery', details: deliveryError }),
        { status: 500, headers: { 'Content-Type': 'application/json' } }
      )
    }

    // Create delivery stops
    const stopsData: DeliveryStop[] = body.dropoffStops.map((stop, index) => ({
      stopNumber: index + 1,
      stopType: 'dropoff',
      address: stop.address,
      latitude: stop.location.lat,
      longitude: stop.location.lng,
      recipientName: stop.contactName,
      recipientPhone: stop.contactPhone,
      deliveryNotes: stop.instructions || null,
      packageDescription: stop.packageDescription || null,
      packageWeight: stop.packageWeight || null,
      status: 'pending',
      deliveryId: delivery.id,
      distanceFromPreviousKm: distances[index],
    }))

    const stopsInsertData = stopsData.map(stop => ({
      delivery_id: stop.deliveryId,
      stop_number: stop.stopNumber,
      stop_type: stop.stopType,
      address: stop.address,
      latitude: stop.latitude,
      longitude: stop.longitude,
      recipient_name: stop.recipientName,
      recipient_phone: stop.recipientPhone,
      delivery_notes: stop.deliveryNotes,
      package_description: stop.packageDescription,
      package_weight: stop.packageWeight,
      status: stop.status,
      distance_from_previous_km: stop.distanceFromPreviousKm,
    }))

    const { error: stopsError } = await supabaseClient
      .from('delivery_stops')
      .insert(stopsInsertData)

    if (stopsError) {
      console.error('Error creating stops:', stopsError)
      // Rollback: delete the delivery
      await supabaseClient.from('deliveries').delete().eq('id', delivery.id)
      
      return new Response(
        JSON.stringify({ error: 'Failed to create delivery stops', details: stopsError }),
        { status: 500, headers: { 'Content-Type': 'application/json' } }
      )
    }

    console.log(`✅ Multi-stop delivery created: ${delivery.id} with ${totalStops} stops`)

    // Return delivery with calculated pricing
    return new Response(
      JSON.stringify({
        ...delivery,
        stops: stopsData,
        pricing: {
          totalKm,
          totalPrice: pricing.totalPrice,
          stopCount: totalStops,
          basePrice: pricing.basePrice,
          distanceCost: pricing.distanceCost,
          multiStopFee: pricing.multiStopFee,
          additionalStopCharge: pricing.additionalStopCharge,
        },
      }),
      {
        status: 200,
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*',
        },
      }
    )
  } catch (error: any) {
    console.error('Unexpected error:', error)
    return new Response(
      JSON.stringify({ error: 'Internal server error', details: error?.message || 'Unknown error' }),
      { status: 500, headers: { 'Content-Type': 'application/json' } }
    )
  }
})
