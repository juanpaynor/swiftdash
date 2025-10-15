# Maya Test Cards - Sandbox Environment

**Date:** October 15, 2025  
**Source:** Maya Developer Portal  
**Environment:** Sandbox

---

## Test Card Details

| Card Type | Number | Expiry Month | Expiry Year | CSC/CVV | 3-D Secure Password | Notes |
|-----------|--------|--------------|-------------|---------|---------------------|-------|
| **MASTERCARD** | `5123456789012346` | 12 | 2025 | 111 | Not enabled | No 3DS - Simple flow |
| **MASTERCARD** | `5453010000064154` | 12 | 2025 | 111 | `secbarry1` | 3DS enabled |
| **VISA** | `4123450131001381` | 12 | 2025 | 123 | `mctest1` | **PRIMARY TEST CARD** ✅ |
| **VISA** | `4123450131001522` | 12 | 2025 | 123 | `mctest1` | Use for declined tests |
| **VISA** | `4123450131004443` | 12 | 2025 | 123 | `mctest1` | Alternative VISA |
| **VISA** | `4123450131000508` | 12 | 2025 | 111 | Not enabled | No 3DS - Simple flow |

---

## Test Scenarios

### 1. Success Flow - No 3DS
**Card:** `5123456789012346` (Mastercard)
- CVV: `111`
- Expiry: `12/2025`
- 3DS: Not enabled
- **Expected:** Payment succeeds immediately without 3DS challenge

### 2. Success Flow - With 3DS
**Card:** `4123450131001381` (Visa) ⭐ **RECOMMENDED**
- CVV: `123`
- Expiry: `12/2025`
- 3DS Password: `mctest1`
- **Expected:** Shows 3DS challenge → Enter password → Payment succeeds

### 3. Declined Payment
**Card:** `4123450131001522` (Visa)
- CVV: `123`
- Expiry: `12/2025`
- 3DS Password: `mctest1`
- **Expected:** Payment declined by bank

### 4. Alternative Success Test
**Card:** `4123450131004443` (Visa)
- CVV: `123`
- Expiry: `12/2025`
- 3DS Password: `mctest1`
- **Expected:** Payment succeeds with 3DS

### 5. Simple No-3DS Visa
**Card:** `4123450131000508` (Visa)
- CVV: `111`
- Expiry: `12/2025`
- 3DS: Not enabled
- **Expected:** Payment succeeds immediately

### 6. Mastercard with 3DS
**Card:** `5453010000064154` (Mastercard)
- CVV: `111`
- Expiry: `12/2025`
- 3DS Password: `secbarry1`
- **Expected:** Shows 3DS challenge → Enter password → Payment succeeds

---

## Testing Strategy

### Phase 1: Basic Payment Flow
1. Use `5123456789012346` (Mastercard, No 3DS)
2. Test: Create checkout → Complete payment → Verify webhook
3. Expected: AUTHORIZED → CAPTURED

### Phase 2: 3DS Flow
1. Use `4123450131001381` (Visa with 3DS) ⭐
2. Test: Create checkout → 3DS challenge → Enter `mctest1` → Complete
3. Expected: AUTHORIZED → CAPTURED

### Phase 3: Declined Payment
1. Use `4123450131001522` (Visa - Declined)
2. Test: Create checkout → Payment fails
3. Expected: PAYMENT_FAILED webhook

### Phase 4: Auth + Capture Flow
1. Use `4123450131001381` (Primary test card)
2. Test: Authorize payment → Wait → Capture payment
3. Expected: AUTHORIZED → (manual capture) → CAPTURED

### Phase 5: Void Flow
1. Use `4123450131001381` (Primary test card)
2. Test: Authorize payment → Void before capture
3. Expected: AUTHORIZED → VOIDED

---

## Important Notes

### 3-D Secure (3DS) Testing
- Cards with 3DS enabled will show a password prompt during checkout
- **Password for Visa cards:** `mctest1`
- **Password for Mastercard `5453010000064154`:** `secbarry1`
- Cards marked "Not enabled" skip 3DS challenge

### Card Behavior
- **All cards are valid** for Maya sandbox
- **Expiry:** All expire in December 2025 (12/2025)
- **CVV:** Use `111` or `123` as specified
- **Amount:** Any amount works in sandbox
- **Currency:** PHP only

### Testing Auth+Capture
For authorization and capture flow:
1. Create checkout with these cards
2. Payment will be AUTHORIZED
3. Use capture function to charge
4. Payment becomes CAPTURED

### Webhook Events
Expected webhook events:
- `PAYMENT_SUCCESS` or `AUTHORIZED` - Payment authorized
- `CAPTURED` - Payment captured (charged)
- `VOIDED` - Authorization cancelled
- `PAYMENT_FAILED` - Payment declined
- `PAYMENT_EXPIRED` - Checkout session expired

---

## Quick Test Commands

### Test 1: Create Checkout (Success)
```bash
curl -X POST https://lygzxmhskkqrntnmxtbb.supabase.co/functions/v1/create-maya-checkout \
  -H "Authorization: Bearer YOUR_USER_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "deliveryId": "test-delivery-1",
    "amount": 200,
    "paymentMethod": "creditCard",
    "customerName": "Test User",
    "customerPhone": "+639171234567",
    "customerEmail": "test@example.com"
  }'
```

### Test 2: Capture Payment
```bash
curl -X POST https://lygzxmhskkqrntnmxtbb.supabase.co/functions/v1/capture-maya-payment \
  -H "Authorization: Bearer YOUR_USER_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "deliveryId": "test-delivery-1"
  }'
```

### Test 3: Void Payment
```bash
curl -X POST https://lygzxmhskkqrntnmxtbb.supabase.co/functions/v1/void-maya-payment \
  -H "Authorization: Bearer YOUR_USER_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "deliveryId": "test-delivery-1",
    "reason": "Customer cancelled"
  }'
```

---

## Card Selection Guide

**Choose based on your test:**

| Test Case | Recommended Card | Why |
|-----------|-----------------|-----|
| Quick success test | `5123456789012346` | No 3DS, fast |
| Full flow test | `4123450131001381` | 3DS enabled, realistic |
| Failure test | `4123450131001522` | Always declines |
| Mastercard test | `5453010000064154` | 3DS with different password |
| Simple Visa | `4123450131000508` | No 3DS, alternative |

**🏆 PRIMARY RECOMMENDATION:** Use `4123450131001381` (Visa with 3DS `mctest1`) for most tests - it's the most realistic flow.

---

**Status:** ✅ Ready for Testing

