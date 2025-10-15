# Maya Applications & Webhooks - Configuration Summary

**Date:** October 15, 2025  
**Time:** 1:45 PM UTC+8  
**Status:** ✅ Webhook Handlers Deployed - Awaiting Maya Portal Configuration

---

## What We Did

### 1. Updated API Keys ✅
- Replaced old keys with new `swiftdash_sandbox` application keys
- **New Public Key:** `pk-MYQ6WQ4dklZzGJlxjcEsKzlNGqTQJkrMLBGCAuduZlJ`
- **New Secret Key:** `sk-j17xGgEM01WcuhoxHTxnWVPYTdGkGBrq79rujK4Agov`
- ✅ Already configured in Supabase

### 2. Created Webhook Handlers ✅
Created and deployed 2 new webhook handlers:

**maya-vault-webhook** (NEW)
- **URL:** `https://lygzxmhskkqrntnmxtbb.supabase.co/functions/v1/maya-vault-webhook`
- **Purpose:** Handle card tokenization events
- **Events:** PAYMENT_TOKEN_CREATED, PAYMENT_TOKEN_UPDATED, PAYMENT_TOKEN_DELETED
- **Features:**
  - Saves card tokens to `customer_payment_methods` table
  - Only saves when customer opts in (saveCard=true)
  - Deactivates expired/used tokens
  - Verifies webhook signature

**maya-paywithmaya-webhook** (NEW)
- **URL:** `https://lygzxmhskkqrntnmxtbb.supabase.co/functions/v1/maya-paywithmaya-webhook`
- **Purpose:** Handle Maya Wallet (QR code) payments
- **Events:** PAYMENT_SUCCESS, PAYMENT_FAILED, PAYMENT_EXPIRED
- **Features:**
  - Auto-capture (no auth+capture flow for wallet)
  - Updates delivery payment status
  - Handles payment failures and expiry
  - Verifies webhook signature

**maya-webhook** (EXISTING)
- **URL:** `https://lygzxmhskkqrntnmxtbb.supabase.co/functions/v1/maya-webhook`
- **Purpose:** Handle checkout/card payment events
- **Events:** AUTHORIZED, CAPTURED, VOIDED, PAYMENT_FAILED, PAYMENT_EXPIRED
- ⚠️ Needs updating to handle auth+capture events

### 3. Created Documentation ✅
- `MAYA_WEBHOOK_CONFIGURATION.md` - Complete setup guide for Maya Portal

---

## What You Need to Do in Maya Portal

### Application 1: swiftdash_sandbox (Checkout) ✅ Created

**Status:** Application exists, needs webhook configuration

**Action Required:**
1. Go to Maya Portal → swiftdash_sandbox → Settings → Webhooks
2. Click "Add Webhook" or "Configure Webhook"
3. **Webhook URL:** 
   ```
   https://lygzxmhskkqrntnmxtbb.supabase.co/functions/v1/maya-webhook
   ```
4. **Events to Subscribe:**
   - AUTHORIZED (or PAYMENT_AUTHORIZED)
   - CAPTURED (or PAYMENT_CAPTURED)
   - VOIDED (or PAYMENT_VOIDED)
   - PAYMENT_FAILED
   - PAYMENT_EXPIRED
5. Click "Create" and **copy the Webhook Secret**
6. Run this command:
   ```powershell
   supabase secrets set MAYA_WEBHOOK_SECRET=whsec_YOUR_ACTUAL_SECRET
   ```

---

### Application 2: swiftdash_vault (Vault) ⏳ Need to Create

**Status:** Not created yet

**Action Required:**
1. Maya Portal → Click "Create Application"
2. **Name:** `swiftdash_vault`
3. **Description:** `Card tokenization and vault for SwiftDash`
4. **Product:** Select "Vault" ✓
5. **Integration:** API
6. **Payment Methods:** Visa, Mastercard, JCB (optional)
7. Click "Create"
8. **Copy the API keys:**
   - Public Key: `pk-xxxxxxxxxxxx`
   - Secret Key: `sk-xxxxxxxxxxxx`
9. Go to Settings → Webhooks → Add Webhook
10. **Webhook URL:**
    ```
    https://lygzxmhskkqrntnmxtbb.supabase.co/functions/v1/maya-vault-webhook
    ```
11. **Events to Subscribe:**
    - PAYMENT_TOKEN_CREATED
    - PAYMENT_TOKEN_UPDATED
    - PAYMENT_TOKEN_DELETED
12. Click "Create" and **copy the Webhook Secret**
13. Run these commands:
    ```powershell
    supabase secrets set MAYA_VAULT_PUBLIC_KEY=pk-YOUR_KEY
    supabase secrets set MAYA_VAULT_SECRET_KEY=sk-YOUR_KEY
    supabase secrets set MAYA_VAULT_WEBHOOK_SECRET=whsec_YOUR_SECRET
    ```

---

### Application 3: swiftdash_paywithmaya (Pay with Maya) ⏳ Need to Create

**Status:** Not created yet

**Action Required:**
1. Maya Portal → Click "Create Application"
2. **Name:** `swiftdash_paywithmaya`
3. **Description:** `Maya Wallet payments for SwiftDash`
4. **Product:** Select "Pay with Maya" ✓
5. **Integration:** API
6. Click "Create"
7. **Copy the API keys:**
   - Public Key: `pk-xxxxxxxxxxxx`
   - Secret Key: `sk-xxxxxxxxxxxx`
8. Go to Settings → Webhooks → Add Webhook
9. **Webhook URL:**
    ```
    https://lygzxmhskkqrntnmxtbb.supabase.co/functions/v1/maya-paywithmaya-webhook
    ```
10. **Events to Subscribe:**
    - PAYMENT_SUCCESS
    - PAYMENT_FAILED
    - PAYMENT_EXPIRED
11. Click "Create" and **copy the Webhook Secret**
12. Run these commands:
    ```powershell
    supabase secrets set MAYA_PAYWITHMAYA_PUBLIC_KEY=pk-YOUR_KEY
    supabase secrets set MAYA_PAYWITHMAYA_SECRET_KEY=sk-YOUR_KEY
    supabase secrets set MAYA_PAYWITHMAYA_WEBHOOK_SECRET=whsec_YOUR_SECRET
    ```

---

## Why 3 Separate Applications?

Maya requires separate applications for each product/solution:

1. **Checkout (swiftdash_sandbox):**
   - Credit/debit card payments
   - Auth+Capture flow
   - Installment payments (we won't use)

2. **Vault (swiftdash_vault):**
   - Card tokenization
   - Save payment methods
   - PCI-DSS compliant storage

3. **Pay with Maya (swiftdash_paywithmaya):**
   - Maya Wallet payments
   - QR code generation
   - Instant payments (no auth+capture)

Each has different webhook events and API endpoints.

---

## Current Status

### ✅ Completed

- [x] Updated Checkout API keys in Supabase
- [x] Created maya-vault-webhook handler
- [x] Created maya-paywithmaya-webhook handler
- [x] Deployed all webhook handlers
- [x] Created configuration documentation

### ⏳ Awaiting Configuration

- [ ] Configure Checkout webhook in Maya Portal
- [ ] Get Checkout webhook secret
- [ ] Create Vault application in Maya Portal
- [ ] Configure Vault webhook
- [ ] Get Vault API keys and webhook secret
- [ ] Create Pay with Maya application
- [ ] Configure Pay with Maya webhook
- [ ] Get Pay with Maya API keys and webhook secret

### 📋 Total Secrets Needed

After all configuration, you should have **9 secrets** in Supabase:

```
✅ MAYA_PUBLIC_KEY                   # Checkout public key (DONE)
✅ MAYA_SECRET_KEY                   # Checkout secret key (DONE)
⏳ MAYA_WEBHOOK_SECRET               # Checkout webhook secret
⏳ MAYA_VAULT_PUBLIC_KEY             # Vault public key
⏳ MAYA_VAULT_SECRET_KEY             # Vault secret key
⏳ MAYA_VAULT_WEBHOOK_SECRET         # Vault webhook secret
⏳ MAYA_PAYWITHMAYA_PUBLIC_KEY       # Pay with Maya public key
⏳ MAYA_PAYWITHMAYA_SECRET_KEY       # Pay with Maya secret key
⏳ MAYA_PAYWITHMAYA_WEBHOOK_SECRET   # Pay with Maya webhook secret
```

---

## Quick Reference

### Webhook URLs (Ready to Use)

```
Checkout:
https://lygzxmhskkqrntnmxtbb.supabase.co/functions/v1/maya-webhook

Vault:
https://lygzxmhskkqrntnmxtbb.supabase.co/functions/v1/maya-vault-webhook

Pay with Maya:
https://lygzxmhskkqrntnmxtbb.supabase.co/functions/v1/maya-paywithmaya-webhook
```

### Deployed Edge Functions

```powershell
PS E:\ondemand\myapp> supabase functions list
```

**Current Functions:**
- ✅ create-maya-checkout
- ✅ capture-maya-payment
- ✅ void-maya-payment
- ✅ maya-webhook (needs update)
- ✅ maya-vault-webhook (NEW)
- ✅ maya-paywithmaya-webhook (NEW)

---

## Next Steps

1. **Immediate:** Complete Maya Portal configuration
   - Configure webhook for swiftdash_sandbox
   - Create swiftdash_vault app
   - Create swiftdash_paywithmaya app
   - Add all secrets to Supabase

2. **After webhooks configured:** Update maya-webhook function
   - Add auth+capture event handlers
   - Test with sandbox cards

3. **Then:** Continue with Flutter app integration
   - Refactor payment_service.dart
   - Create saved_cards_service.dart
   - Update UI with fee breakdown

---

## Testing After Configuration

Once all webhooks are configured, test each:

**Test Checkout Webhook:**
```powershell
# Make a test payment with card
# Check logs
supabase functions logs maya-webhook --limit 20
```

**Test Vault Webhook:**
```powershell
# Save a card during checkout
# Check logs
supabase functions logs maya-vault-webhook --limit 20
```

**Test Pay with Maya Webhook:**
```powershell
# Make payment with Maya Wallet
# Check logs
supabase functions logs maya-paywithmaya-webhook --limit 20
```

---

**Status:** ✅ Ready for Maya Portal Configuration

**Estimated Time:** 20-30 minutes to complete all portal setup

**Last Updated:** October 15, 2025 @ 1:45 PM UTC+8

