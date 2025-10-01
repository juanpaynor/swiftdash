# Driver App Integration Guide

## Complete Functions Architecture Explanation

Since you're using the simplified approach (no `driver_offers` table), here's exactly how our Edge Functions work and how they integrate with your driver app:

## 📋 Function 1: `quote` - Pricing Calculator

```typescript
// Endpoint: https://[project].supabase.co/functions/v1/quote
// Method: POST
// Purpose: Calculate delivery pricing before booking

// Input JSON:
{
  "vehicleTypeId": "uuid",
  "pickup": {"lat": 14.5995, "lng": 121.0581},
  "dropoff": {"lat": 14.6042, "lng": 121.0744},
  "weightKg": 2.5,        // optional
  "surge": 1.2            // optional surge multiplier
}

// Output JSON:
{
  "basePrice": 50.00,
  "distancePrice": 25.00,
  "totalPrice": 75.00,
  "distanceKm": 5.2,
  "estimatedDuration": 15  // minutes
}
```

## 📦 Function 2: `book_delivery` - Delivery Creation

```typescript
// Endpoint: https://[project].supabase.co/functions/v1/book_delivery  
// Method: POST
// Purpose: Create delivery with trusted server-side pricing

// Input JSON:
{
  "vehicleTypeId": "uuid",
  "pickup": {
    "address": "123 Main St, Manila",
    "location": {"lat": 14.5995, "lng": 121.0581},
    "contactName": "John Doe",
    "contactPhone": "+639123456789",
    "instructions": "Gate 2"  // optional
  },
  "dropoff": {
    "address": "456 Oak Ave, Quezon City", 
    "location": {"lat": 14.6042, "lng": 121.0744},
    "contactName": "Jane Smith",
    "contactPhone": "+639987654321",
    "instructions": "Apartment 5B"  // optional
  },
  "package": {
    "description": "Documents",
    "weightKg": 0.5,       // optional
    "value": 1000.00       // optional
  }
}

// Output JSON: Complete Delivery Object
{
  "id": "delivery-uuid",
  "customer_id": "user-uuid",
  "driver_id": null,           // ← Initially null
  "status": "pending",         // ← Ready for your driver assignment
  "pickup_latitude": 14.5995,
  "pickup_longitude": 121.0581,
  "delivery_latitude": 14.6042,
  "delivery_longitude": 121.0744,
  "total_price": 75.00,
  "created_at": "2025-10-01T10:30:00Z",
  // ... all other delivery fields
}
```

## 🎯 Function 3: `pair_driver` - Driver Assignment (THE KEY ONE)

```typescript
// Endpoint: https://[project].supabase.co/functions/v1/pair_driver
// Method: POST  
// Purpose: Find closest driver and assign to delivery

// Input JSON:
{
  "deliveryId": "delivery-uuid"
}

// What it does internally:
// 1. Gets delivery pickup coordinates
// 2. Queries driver_profiles for available drivers:
//    WHERE is_online = true AND is_available = true
// 3. Calculates distances (PostGIS or Haversine fallback)
// 4. Assigns CLOSEST driver to delivery:
//    UPDATE deliveries SET 
//      driver_id = 'closest-driver-uuid',
//      status = 'driver_assigned'
//    WHERE id = deliveryId

// Output JSON:
{
  "ok": true,
  "delivery_id": "delivery-uuid",
  "assigned_driver_id": "driver-uuid",    // ← YOUR DRIVER GETS THIS
  "drivers_found": 3,
  "closest_driver_distance": 2.1          // km
}
```

## 🔄 Integration Flow with Your Driver App

### Step 1: Customer Creates Delivery
```
Customer App → book_delivery → Creates delivery with status: "pending"
```

### Step 2: Customer Requests Driver  
```
Customer App → pair_driver → Assigns to YOUR closest driver
Database: deliveries.driver_id = your_driver_uuid
Database: deliveries.status = "driver_assigned"
```

### Step 3: Your Driver App Reacts
```
Your realtime subscription detects:
- New delivery where driver_id = current_driver
- Status = "driver_assigned" 
- Show full-screen modal with 5-minute timer
```

### Step 4: Driver Response
```
Driver Accepts → Your app updates:
UPDATE deliveries SET status = 'pickup_arrived' WHERE id = delivery_id

Driver Declines → We need to handle reassignment
UPDATE deliveries SET driver_id = null, status = 'pending' WHERE id = delivery_id
Then call pair_driver again for next closest driver
```

## 🗃️ Database Tables You Need to Monitor

### deliveries table (shared):
```sql
-- Monitor this for assignments
SELECT * FROM deliveries 
WHERE driver_id = 'your-driver-uuid' 
  AND status = 'driver_assigned'
```

### driver_profiles table (your table):
```sql  
-- Keep this updated
UPDATE driver_profiles SET
  current_latitude = 14.5995,
  current_longitude = 121.0581,
  location_updated_at = now(),
  is_available = true,
  is_online = true
WHERE driver_id = 'your-driver-uuid'
```

## 🚨 Critical Integration Points

1. **Real-time Subscriptions:** Your app should subscribe to `deliveries` table changes
2. **Driver Availability:** Keep `driver_profiles.is_available` accurate  
3. **Location Updates:** Update coordinates every 15 seconds when online
4. **Status Management:** Update `deliveries.status` as driver progresses

## ❓ Questions for Integration

1. **Decline Handling:** How should we handle when your driver declines? Auto-reassign to next closest?
2. **Timeout Handling:** If driver doesn't respond in 5 minutes, should we auto-reassign?
3. **Database Triggers:** Do you want me to create any triggers for automatic status updates?

## 🧪 Ready to Test

Your driver app just needs to:
- Subscribe to `deliveries` table for new assignments
- Show offer modal when `driver_id = your_driver AND status = 'driver_assigned'`
- Update status when driver accepts/declines

**The functions are live and ready!** 🚀

---

*Generated on October 1, 2025 - Customer App AI*