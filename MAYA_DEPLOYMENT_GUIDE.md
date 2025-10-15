# Maya API - Deployment Guide

**Date:** October 15, 2025  
**Environment:** Starting with Sandbox  
**Status:** Ready to Deploy

---

## Prerequisites ✅

- [x] Database migration applied (customer_payment_methods table created)
- [x] Flutter dependencies installed (webview_flutter, http)
- [x] Maya sandbox credentials available in `.env`
- [x] Edge functions created (create-maya-checkout, capture-maya-payment, void-maya-payment)
- [x] Test cards documented

---

## Step 1: Set Supabase Secrets

Run these commands to add Maya credentials to Supabase:

```powershell
# Set Maya API keys
supabase secrets set MAYA_PUBLIC_KEY=pk-lNAUk1jk7VPnf7koOT1uoGJoZJjmAxrbjpj6urB8EIA
supabase secrets set MAYA_SECRET_KEY=sk-fzukI3GXrzNIUyvXY3n16cji8VTJITfzylz5o5QzZMC
supabase secrets set MAYA_ENVIRONMENT=sandbox

# Set webhook secret (get this from Maya dashboard after webhook registration)
# For now, we'll set a placeholder - update after registering webhook
supabase secrets set MAYA_WEBHOOK_SECRET=placeholder_will_update_after_webhook_registration
```

### Verify Secrets
```powershell
supabase secrets list
```

**Expected output:**
```
MAYA_PUBLIC_KEY: pk-lNAUk1jk7VPnf7koOT1uoGJoZJjmAxrbjpj6urB8EIA
MAYA_SECRET_KEY: sk-fz*** (masked)
MAYA_ENVIRONMENT: sandbox
MAYA_WEBHOOK_SECRET: plac*** (masked)
```

---

## Step 2: Deploy Edge Functions

Deploy the three Maya payment functions:

```powershell
# Navigate to project directory
cd E:\ondemand\myapp

# Deploy create-maya-checkout function
supabase functions deploy create-maya-checkout

# Deploy capture-maya-payment function
supabase functions deploy capture-maya-payment

# Deploy void-maya-payment function
supabase functions deploy void-maya-payment
```

### Verify Deployment
```powershell
supabase functions list
```

**Expected output:**
```
NAME                      SLUG                      VERSION  STATUS
create-maya-checkout      create-maya-checkout      v1       ACTIVE
capture-maya-payment      capture-maya-payment      v1       ACTIVE
void-maya-payment         void-maya-payment         v1       ACTIVE
maya-webhook              maya-webhook              v1       ACTIVE (existing)
```

---

## Step 3: Register Webhook with Maya

### 3.1 Get Your Webhook URL

Your webhook URL is:
```
https://lygzxmhskkqrntnmxtbb.supabase.co/functions/v1/maya-webhook
```

### 3.2 Register in Maya Developer Portal

1. **Login to Maya Developer Portal:**
   - Go to: https://developers.maya.ph/
   - Login with your account

2. **Navigate to Webhooks:**
   - Dashboard → Settings → Webhooks
   - Click "Add Webhook"

3. **Configure Webhook:**
   - **URL:** `https://lygzxmhskkqrntnmxtbb.supabase.co/functions/v1/maya-webhook`
   - **Events to subscribe:**
     - [x] `PAYMENT_SUCCESS` (or `AUTHORIZED`)
     - [x] `CAPTURED`
     - [x] `VOIDED`
     - [x] `PAYMENT_FAILED`
     - [x] `PAYMENT_EXPIRED`
   - **Environment:** Sandbox
   - Click "Create"

4. **Copy Webhook Secret:**
   - After creating, Maya will show you a "Webhook Secret"
   - Copy this secret (looks like: `whsec_xxxxx`)
   - **IMPORTANT:** Save this - you can't see it again!

### 3.3 Update Webhook Secret in Supabase

```powershell
# Replace YOUR_WEBHOOK_SECRET with the actual secret from Maya
supabase secrets set MAYA_WEBHOOK_SECRET=whsec_YOUR_ACTUAL_SECRET_HERE
```

### 3.4 Verify Webhook Registration

Test webhook by triggering a payment in sandbox:
```powershell
# Check Supabase function logs
supabase functions logs maya-webhook --follow
```

---

## Step 4: Test Deployment

### Test 1: Create Checkout (Manual Test)

1. **Get a user token:**
   ```powershell
   # Option A: Use Supabase service role key for testing
   $TOKEN = "YOUR_SUPABASE_SERVICE_ROLE_KEY"
   
   # Option B: Login via app and get user token
   ```

2. **Call create-maya-checkout:**
   ```powershell
   curl -X POST `
     "https://lygzxmhskkqrntnmxtbb.supabase.co/functions/v1/create-maya-checkout" `
     -H "Authorization: Bearer $TOKEN" `
     -H "Content-Type: application/json" `
     -d '{
       "deliveryId": "test-001",
       "amount": 200,
       "paymentMethod": "creditCard",
       "customerName": "Test User",
       "customerPhone": "+639171234567",
       "customerEmail": "test@example.com"
     }'
   ```

3. **Expected Response:**
   ```json
   {
     "success": true,
     "checkoutId": "ch_xxxxxxxxxx",
     "checkoutUrl": "https://pg-sandbox.paymaya.com/checkout/...",
     "expiresAt": "2025-10-15T12:00:00Z",
     "totalAmount": 222.00,
     "processingFee": 22.00
   }
   ```

4. **Open checkout URL:**
   - Copy the `checkoutUrl` from response
   - Open in browser
   - Should see Maya payment page

5. **Complete payment:**
   - Card: `4123450131001381`
   - CVV: `123`
   - Expiry: `12/2025`
   - 3DS Password: `mctest1`
   - Click "Pay Now"

6. **Verify webhook received:**
   ```powershell
   # Check logs
   supabase functions logs maya-webhook --limit 10
   ```

### Test 2: Capture Payment

1. **Create test delivery with authorized payment:**
   - Complete Test 1 above
   - Note the `deliveryId`

2. **Call capture function:**
   ```powershell
   curl -X POST `
     "https://lygzxmhskkqrntnmxtbb.supabase.co/functions/v1/capture-maya-payment" `
     -H "Authorization: Bearer $TOKEN" `
     -H "Content-Type: application/json" `
     -d '{
       "deliveryId": "test-001"
     }'
   ```

3. **Expected Response:**
   ```json
   {
     "success": true,
     "paymentId": "pay_xxxxxxxxxx",
     "capturedAmount": 222.00,
     "capturedAt": "2025-10-15T10:30:00Z"
   }
   ```

### Test 3: Void Payment

1. **Create another test delivery:**
   - Complete checkout but DON'T capture yet

2. **Call void function:**
   ```powershell
   curl -X POST `
     "https://lygzxmhskkqrntnmxtbb.supabase.co/functions/v1/void-maya-payment" `
     -H "Authorization: Bearer $TOKEN" `
     -H "Content-Type: application/json" `
     -d '{
       "deliveryId": "test-002",
       "reason": "Testing void functionality"
     }'
   ```

3. **Expected Response:**
   ```json
   {
     "success": true,
     "voidedAt": "2025-10-15T11:00:00Z",
     "reason": "Testing void functionality"
   }
   ```

---

## Step 5: Verify Database Updates

Check that payment data is being stored correctly:

```sql
-- Check customer payment methods (if any were saved)
SELECT * FROM customer_payment_methods;

-- Check delivery payment status
SELECT 
  id,
  payment_status,
  payment_authorization_id,
  payment_authorized_at,
  payment_captured_at,
  payment_void_at,
  payment_total_amount,
  payment_processing_fee
FROM deliveries
WHERE id = 'test-001';

-- Check webhook logs
SELECT 
  event_type,
  signature_verified,
  processed,
  received_at
FROM payment_webhook_logs
ORDER BY received_at DESC
LIMIT 10;
```

---

## Step 6: Monitor Function Logs

### Real-time Monitoring
```powershell
# Watch all Maya functions
supabase functions logs create-maya-checkout --follow
supabase functions logs capture-maya-payment --follow
supabase functions logs void-maya-payment --follow
supabase functions logs maya-webhook --follow
```

### Recent Errors
```powershell
# Show recent errors
supabase functions logs create-maya-checkout --limit 50 | findstr "error"
```

---

## Troubleshooting

### Issue 1: "Maya API keys not configured"
**Solution:** Verify secrets are set
```powershell
supabase secrets list
```

### Issue 2: "Invalid authorization token"
**Solution:** Get a fresh user token or use service role key for testing

### Issue 3: Webhook not received
**Possible causes:**
- Webhook URL not registered in Maya portal
- Webhook secret mismatch
- Network/firewall blocking webhooks

**Debug:**
```powershell
# Check webhook logs
supabase functions logs maya-webhook --limit 20

# Check if webhook endpoint is accessible
curl https://lygzxmhskkqrntnmxtbb.supabase.co/functions/v1/maya-webhook
```

### Issue 4: Payment authorization failed
**Check:**
- Maya sandbox is working (try in Maya dashboard)
- Card details are correct (see MAYA_TEST_CARDS.md)
- Amount is valid (> 0)

### Issue 5: Capture/Void failed
**Check:**
- Payment status is 'authorized'
- Authorization hasn't expired (check payment_auto_void_at)
- Authorization ID exists in database

---

## Post-Deployment Checklist

- [ ] All 4 edge functions deployed successfully
- [ ] Maya secrets configured in Supabase
- [ ] Webhook registered in Maya portal
- [ ] Webhook secret updated in Supabase
- [ ] Test checkout created successfully
- [ ] Test payment completed with test card
- [ ] Webhook received and logged
- [ ] Database updated with payment data
- [ ] Capture test successful
- [ ] Void test successful
- [ ] Function logs show no errors

---

## Next Steps After Successful Deployment

1. **Update maya-webhook function** to handle all auth/capture events
2. **Refactor payment_service.dart** in Flutter app
3. **Create saved cards service** in Flutter
4. **Update UI** to show fee breakdown
5. **Test end-to-end flow** in Flutter app
6. **Create auto-void cron job** for expired authorizations

---

## Production Deployment (Later)

When ready for production:

1. **Get production API keys** from Maya
2. **Update secrets:**
   ```powershell
   supabase secrets set MAYA_PUBLIC_KEY=pk-prod-xxxxx
   supabase secrets set MAYA_SECRET_KEY=sk-prod-xxxxx
   supabase secrets set MAYA_ENVIRONMENT=production
   ```
3. **Re-register webhook** with production URL
4. **Test with real card** (small amount first)
5. **Monitor closely** for first 24 hours
6. **Have rollback plan** ready

---

**Status:** ✅ Ready to Deploy

**Estimated Time:** 30-45 minutes

**Last Updated:** October 15, 2025

