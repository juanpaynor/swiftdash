# Maya Auth+Capture Implementation - Updated to Official API

**Date:** October 15, 2025  
**Status:** ✅ Updated to Match Maya's Official Documentation

---

## 📚 What Changed

Based on Maya's official guide (`maya_guide.md`), we've updated our implementation to use the correct endpoints and flow.

---

## 🔄 Key Changes Made

### 1. Create Checkout - Added `authorizationType`

**Before:** No authorization type specified
**After:** Added `authorizationType: "NORMAL"` to checkout request

```typescript
const mayaCheckoutRequest = {
  authorizationType: 'NORMAL', // NEW! Enables auth+capture flow
  totalAmount: { value: totalAmount, currency: 'PHP' },
  buyer: { ... },
  items: [ ... ],
  redirectUrl: { ... },
  // ...
}
```

**What this does:**
- `NORMAL` = Can capture up to the authorized amount
- Hold period: **6 days**
- After 6 days, Maya automatically releases the hold

### 2. Capture Endpoint - Corrected API Path

**Before (Incorrect):**
```
POST /payments/v1/payment-rrns/{id}/capture
```

**After (Correct):**
```
POST /payments/v1/payments/{paymentId}/capture
```

**Key Change:** Uses `checkoutId` (returned from Create Checkout) as the `paymentId`

### 3. Database - Added `maya_checkout_id` Column

**New migration:** `20251015_add_maya_checkout_id.sql`

```sql
ALTER TABLE deliveries 
  ADD COLUMN IF NOT EXISTS maya_checkout_id TEXT;
```

**Why:** The `checkoutId` from Maya's response is needed for capture/void operations

---

## 📖 Maya Auth+Capture Flow (Official)

### Step 1: Create Authorization (Hold)

```typescript
// Customer clicks "Pay" button
POST /checkout/v1/checkouts
{
  "authorizationType": "NORMAL",  // ← Key field!
  "totalAmount": { "value": 222, "currency": "PHP" },
  "buyer": { ... },
  "items": [ ... ],
  "redirectUrl": {
    "success": "swiftdash://payment/success",
    "failure": "swiftdash://payment/failure",
    "cancel": "swiftdash://payment/cancel"
  }
}

// Response:
{
  "checkoutId": "ck_abc123xyz",  // ← This is the paymentId!
  "redirectUrl": "https://pg-sandbox.paymaya.com/checkout/...",
  "expiresAt": "2025-10-15T14:00:00Z"
}
```

**What happens:**
1. Customer redirected to Maya checkout page
2. Enters card details and completes 3DS
3. Maya **authorizes** (holds) ₱222 on their card
4. Webhook sent: `AUTHORIZED` status
5. Hold valid for **6 days**

---

### Step 2: Capture Payment (When Driver Accepts)

```typescript
// Driver accepts delivery
POST /payments/v1/payments/{checkoutId}/capture
{
  "requestReferenceNumber": "CAPTURE_delivery123_1234567890"
}

// Response:
{
  "id": "cap_xyz789",
  "status": "CAPTURED",
  "amount": 222
}
```

**What happens:**
1. Maya **charges** the customer's card
2. Funds transferred to merchant (you)
3. Webhook sent: `CAPTURED` status
4. Authorization intent → `CAPTURED` state

---

### Step 3: Void Payment (If No Driver or Cancelled)

```typescript
// No driver found or customer cancels
POST /payments/v1/payments/{checkoutId}/void
{
  "requestReferenceNumber": "VOID_delivery123_1234567890"
}

// Response:
{
  "id": "void_abc456",
  "status": "VOIDED"
}
```

**What happens:**
1. Maya **releases** the hold immediately
2. Customer NOT charged
3. Webhook sent: `VOIDED` status

---

## 🎯 Authorization Types (Maya's Options)

| Type | Capture Amount | Hold Period | Use Case |
|------|----------------|-------------|----------|
| **NORMAL** | ≤ authorized amount | 6 days | ✅ **Our choice** - Standard delivery payments |
| **FINAL** | = authorized amount (full) | 6 days | Must capture exact amount |
| **PREAUTHORIZATION** | ≤ authorized amount | 29 days* | Hotels, car rentals, long bookings |

*PREAUTHORIZATION hold periods vary by card scheme:
- MasterCard: 29 days
- Visa: 29 days (lodging/vehicles), 6 days (others)
- JCB/AMEX: 6 days

**Why we chose NORMAL:**
- Flexible capture amount (can capture less if needed)
- 6-day hold is enough for driver matching
- Simpler than PREAUTHORIZATION
- No special requirements

---

## 📊 Payment Status Lifecycle

```
Customer Books Delivery
         ↓
   [PENDING] ← checkout created
         ↓
   Customer completes payment
         ↓
   [AUTHORIZED] ← funds on hold (6 days)
         ↓
    ┌────┴────┐
    ↓         ↓
Driver     No Driver
Accepts    (timeout)
    ↓         ↓
[CAPTURED] [VOIDED]
(charged)  (released)
    ↓         ↓
  [DONE]   [DONE]
```

---

## 🔧 What We Updated

### ✅ 1. create-maya-checkout function
- Added `authorizationType: "NORMAL"` to request
- Stores `checkoutId` as `maya_checkout_id` in database

### ✅ 2. capture-maya-payment function
- Changed endpoint from `/payment-rrns/{id}/capture` to `/payments/{paymentId}/capture`
- Uses `maya_checkout_id` instead of `payment_authorization_id`
- Sends optional `totalAmount` for partial captures

### ✅ 3. Database schema
- Added `maya_checkout_id` column to deliveries
- Added index for efficient lookups
- Kept `payment_authorization_id` for backwards compatibility

### ✅ 4. Redeployed functions
- `create-maya-checkout` - v3 deployed
- `capture-maya-payment` - v3 deployed
- `void-maya-payment` - already correct (uses same endpoint pattern)

---

## 🧪 Testing Checklist

### Test 1: Authorization (Hold)
```powershell
# Create checkout
curl -X POST `
  "https://lygzxmhskkqrntnmxtbb.supabase.co/functions/v1/create-maya-checkout" `
  -H "Authorization: Bearer YOUR_TOKEN" `
  -H "Content-Type: application/json" `
  -d '{
    "deliveryId": "test-auth-001",
    "amount": 200,
    "paymentMethod": "creditCard",
    "customerName": "Test User",
    "customerPhone": "+639171234567"
  }'

# Expected: checkoutUrl returned
# Complete payment with test card: 4123450131001381
# Expected: Webhook event AUTHORIZED received
# Check database: payment_status = 'authorized'
```

### Test 2: Capture
```powershell
# After authorization complete
curl -X POST `
  "https://lygzxmhskkqrntnmxtbb.supabase.co/functions/v1/capture-maya-payment" `
  -H "Authorization: Bearer YOUR_TOKEN" `
  -H "Content-Type: application/json" `
  -d '{"deliveryId": "test-auth-001"}'

# Expected: Webhook event CAPTURED received
# Check database: payment_status = 'paid', payment_captured_at set
```

### Test 3: Void (Cancel)
```powershell
# Create another authorization
# Before capturing, void it
curl -X POST `
  "https://lygzxmhskkqrntnmxtbb.supabase.co/functions/v1/void-maya-payment" `
  -H "Authorization: Bearer YOUR_TOKEN" `
  -H "Content-Type: application/json" `
  -d '{"deliveryId": "test-auth-002"}'

# Expected: Webhook event VOIDED received
# Check database: payment_status = 'voided', payment_void_at set
```

---

## ⚠️ Important Notes

### Hold Expiration
- **6 days** for NORMAL authorizations
- Maya automatically releases holds after expiration
- **Our auto-void job should run BEFORE 6 days** (recommend 24 hours)

### Multiple Captures
- Can capture **multiple times** on same day as first capture
- Total captured ≤ authorized amount
- After 11:59 PM, no more captures allowed (status → DONE)

### Partial Captures
- Can capture **less** than authorized amount
- Example: Authorized ₱222, capture only ₱200 (if delivery fee reduced)
- Remaining amount released automatically

### Expired Authorizations
- Can't capture after 6 days
- API returns error: `PY0103 Payment is already expired`
- Status → `CAPTURE_HOLD_EXPIRED`

---

## 📝 Summary

**What's Different:**
1. ✅ Using official Maya Checkout API (`/checkout/v1/checkouts`)
2. ✅ Correct `authorizationType: "NORMAL"` field
3. ✅ Correct capture endpoint (`/payments/{paymentId}/capture`)
4. ✅ Using `checkoutId` as `paymentId` for operations
5. ✅ 6-day authorization hold period

**What's the Same:**
- Overall auth+capture flow concept
- Fee calculation (3.5% + ₱15 for cards)
- Webhook handling
- Void/cancel logic
- Database structure (just added one column)

**Status:** ✅ Implementation now matches Maya's official documentation!

---

**Next Steps:**
1. Add the webhook URLs in Maya Portal
2. Test with sandbox environment
3. Update maya-webhook function to handle AUTHORIZED/CAPTURED/VOIDED events
4. Create auto-void cron job (before 6-day expiry)
5. Start Flutter app integration

---

**Last Updated:** October 15, 2025 @ 2:45 PM UTC+8

