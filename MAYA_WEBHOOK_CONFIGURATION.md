# Maya Webhook Configuration Guide

**Date:** October 15, 2025  
**Status:** ✅ Ready to Configure

---

## Overview

You need to create **3 separate applications** in Maya Developer Portal, each with its own webhook:

1. **Checkout Application** (swiftdash_sandbox) - Main payment processing
2. **Vault Application** - Card tokenization and saved cards
3. **Pay with Maya Application** - Maya Wallet QR code payments

Each application has:
- Unique Public Key (pk-*)
- Unique Secret Key (sk-*)
- Unique Webhook URL
- Unique Webhook Secret

---

## Current Configuration

### API Keys (Already Set in Supabase)

**Checkout Application (swiftdash_sandbox):**
- Public Key: `pk-MYQ6WQ4dklZzGJlxjcEsKzlNGqTQJkrMLBGCAuduZlJ`
- Secret Key: `sk-j17xGgEM01WcuhoxHTxnWVPYTdGkGBrq79rujK4Agov`
- ✅ Already configured in Supabase as `MAYA_PUBLIC_KEY` and `MAYA_SECRET_KEY`

### Webhook URLs (Deployed and Ready)

All webhook handlers are deployed at:

1. **Checkout Webhook:**
   ```
   https://lygzxmhskkqrntnmxtbb.supabase.co/functions/v1/maya-webhook
   ```
   - Handles: AUTHORIZED, CAPTURED, VOIDED, FAILED, EXPIRED
   - Edge Function: `supabase/functions/maya-webhook/index.ts`

2. **Vault Webhook:**
   ```
   https://lygzxmhskkqrntnmxtbb.supabase.co/functions/v1/maya-vault-webhook
   ```
   - Handles: PAYMENT_TOKEN_CREATED, PAYMENT_TOKEN_UPDATED, PAYMENT_TOKEN_DELETED
   - Edge Function: `supabase/functions/maya-vault-webhook/index.ts`

3. **Pay with Maya Webhook:**
   ```
   https://lygzxmhskkqrntnmxtbb.supabase.co/functions/v1/maya-paywithmaya-webhook
   ```
   - Handles: PAYMENT_SUCCESS, PAYMENT_FAILED, PAYMENT_EXPIRED
   - Edge Function: `supabase/functions/maya-paywithmaya-webhook/index.ts`

---

## Step-by-Step Configuration

### Step 1: Access Maya Developer Portal

1. Go to: https://developers.maya.ph/
2. Login with your account
3. Navigate to **Dashboard**

---

### Step 2: Configure Checkout Application (swiftdash_sandbox)

This is the application you already created!

#### 2.1 Navigate to Webhook Settings
- Select application: **swiftdash_sandbox**
- Go to: **Settings → Webhooks**

#### 2.2 Add Checkout Webhook
- Click **"Add Webhook"** or **"Configure Webhook"**
- Fill in:
  - **Webhook URL:** 
    ```
    https://lygzxmhskkqrntnmxtbb.supabase.co/functions/v1/maya-webhook
    ```
  - **Description:** `SwiftDash Checkout Events`
  - **Events to Subscribe:**
    - [x] `AUTHORIZED` (or `PAYMENT_AUTHORIZED`)
    - [x] `CAPTURED` (or `PAYMENT_CAPTURED`)
    - [x] `VOIDED` (or `PAYMENT_VOIDED`)
    - [x] `PAYMENT_FAILED`
    - [x] `PAYMENT_EXPIRED`

#### 2.3 Save and Get Webhook Secret
- Click **"Create"** or **"Save"**
- Maya will display a **Webhook Secret** (looks like: `whsec_xxxxxxxxxxxxx`)
- **COPY THIS SECRET** - You can't see it again!
- Example: `whsec_abc123xyz456def789`

#### 2.4 Add Secret to Supabase
Run this command in PowerShell (replace with your actual secret):
```powershell
supabase secrets set MAYA_WEBHOOK_SECRET=whsec_YOUR_ACTUAL_SECRET_HERE
```

---

### Step 3: Create Vault Application

#### 3.1 Create New Application
- In Maya Dashboard, click **"Create Application"**
- Fill in:
  - **Name:** `swiftdash_vault`
  - **Description:** `Card tokenization and vault for SwiftDash`
  - **Environment:** Sandbox

#### 3.2 Select Product
- Under **"Configure Product"**, select:
  - **Product:** `Vault` ✓
  - **Integration:** `API`

#### 3.3 Select Payment Methods
- Select which cards can be vaulted:
  - [x] Visa
  - [x] Mastercard
  - [x] JCB (optional)

#### 3.4 Create Application
- Click **"Next"** → **"Create"**
- Maya will generate:
  - **Public Key:** `pk-xxxxxxxxxxxx` (copy this)
  - **Secret Key:** `sk-xxxxxxxxxxxx` (copy this)

#### 3.5 Configure Vault Webhook
- Go to: **Settings → Webhooks**
- Click **"Add Webhook"**
- Fill in:
  - **Webhook URL:** 
    ```
    https://lygzxmhskkqrntnmxtbb.supabase.co/functions/v1/maya-vault-webhook
    ```
  - **Description:** `SwiftDash Vault Events`
  - **Events to Subscribe:**
    - [x] `PAYMENT_TOKEN_CREATED`
    - [x] `PAYMENT_TOKEN_UPDATED`
    - [x] `PAYMENT_TOKEN_DELETED`

#### 3.6 Save Keys and Secret
- **Public Key:** `pk-xxxxxxxxxxxx`
- **Secret Key:** `sk-xxxxxxxxxxxx`
- **Webhook Secret:** `whsec_xxxxxxxxxxxx`

Add to Supabase:
```powershell
supabase secrets set MAYA_VAULT_PUBLIC_KEY=pk-YOUR_VAULT_PUBLIC_KEY
supabase secrets set MAYA_VAULT_SECRET_KEY=sk-YOUR_VAULT_SECRET_KEY
supabase secrets set MAYA_VAULT_WEBHOOK_SECRET=whsec-YOUR_VAULT_WEBHOOK_SECRET
```

---

### Step 4: Create Pay with Maya Application

#### 4.1 Create New Application
- In Maya Dashboard, click **"Create Application"**
- Fill in:
  - **Name:** `swiftdash_paywithmaya`
  - **Description:** `Maya Wallet payments for SwiftDash`
  - **Environment:** Sandbox

#### 4.2 Select Product
- Under **"Configure Product"**, select:
  - **Product:** `Pay with Maya` ✓
  - **Integration:** `API`

#### 4.3 Create Application
- Click **"Next"** → **"Create"**
- Maya will generate:
  - **Public Key:** `pk-xxxxxxxxxxxx` (copy this)
  - **Secret Key:** `sk-xxxxxxxxxxxx` (copy this)

#### 4.4 Configure Pay with Maya Webhook
- Go to: **Settings → Webhooks**
- Click **"Add Webhook"**
- Fill in:
  - **Webhook URL:** 
    ```
    https://lygzxmhskkqrntnmxtbb.supabase.co/functions/v1/maya-paywithmaya-webhook
    ```
  - **Description:** `SwiftDash Pay with Maya Events`
  - **Events to Subscribe:**
    - [x] `PAYMENT_SUCCESS`
    - [x] `PAYMENT_FAILED`
    - [x] `PAYMENT_EXPIRED`

#### 4.5 Save Keys and Secret
- **Public Key:** `pk-xxxxxxxxxxxx`
- **Secret Key:** `sk-xxxxxxxxxxxx`
- **Webhook Secret:** `whsec_xxxxxxxxxxxx`

Add to Supabase:
```powershell
supabase secrets set MAYA_PAYWITHMAYA_PUBLIC_KEY=pk-YOUR_PAYWITHMAYA_PUBLIC_KEY
supabase secrets set MAYA_PAYWITHMAYA_SECRET_KEY=sk-YOUR_PAYWITHMAYA_SECRET_KEY
supabase secrets set MAYA_PAYWITHMAYA_WEBHOOK_SECRET=whsec_YOUR_PAYWITHMAYA_WEBHOOK_SECRET
```

---

## Step 5: Verify All Secrets

After configuring all webhooks, verify all secrets are set:

```powershell
supabase secrets list
```

**Expected Output (9 secrets):**
```
MAYA_PUBLIC_KEY                   # Checkout public key
MAYA_SECRET_KEY                   # Checkout secret key
MAYA_WEBHOOK_SECRET               # Checkout webhook secret
MAYA_VAULT_PUBLIC_KEY             # Vault public key
MAYA_VAULT_SECRET_KEY             # Vault secret key
MAYA_VAULT_WEBHOOK_SECRET         # Vault webhook secret
MAYA_PAYWITHMAYA_PUBLIC_KEY       # Pay with Maya public key
MAYA_PAYWITHMAYA_SECRET_KEY       # Pay with Maya secret key
MAYA_PAYWITHMAYA_WEBHOOK_SECRET   # Pay with Maya webhook secret
```

---

## Step 6: Test Webhooks

### Test Checkout Webhook

1. **Trigger a test payment:**
   - Use test card: `4123450131001381`
   - Complete payment in Maya checkout

2. **Check webhook logs:**
   ```powershell
   supabase functions logs maya-webhook --limit 20
   ```

3. **Verify in database:**
   ```sql
   SELECT * FROM payment_webhook_logs 
   WHERE event_type LIKE '%AUTHORIZED%' 
   ORDER BY received_at DESC LIMIT 5;
   ```

### Test Vault Webhook

1. **Create a payment token:**
   - Complete checkout with "Save this card" checked
   - Token should be created automatically

2. **Check webhook logs:**
   ```powershell
   supabase functions logs maya-vault-webhook --limit 20
   ```

3. **Verify card saved:**
   ```sql
   SELECT * FROM customer_payment_methods 
   ORDER BY created_at DESC LIMIT 5;
   ```

### Test Pay with Maya Webhook

1. **Generate Maya Wallet QR code:**
   - Select "Pay with Maya Wallet" option
   - Scan QR code with Maya app

2. **Check webhook logs:**
   ```powershell
   supabase functions logs maya-paywithmaya-webhook --limit 20
   ```

3. **Verify payment status:**
   ```sql
   SELECT id, payment_status, payment_method 
   FROM deliveries 
   WHERE payment_method = 'maya_wallet' 
   ORDER BY created_at DESC LIMIT 5;
   ```

---

## Summary

### What You Need to Do in Maya Portal:

1. ✅ **swiftdash_sandbox (Checkout)** - Already created
   - Configure webhook URL
   - Get webhook secret
   - Add to Supabase

2. ⏳ **swiftdash_vault (Vault)** - Need to create
   - Create application
   - Configure webhook URL
   - Get keys and webhook secret
   - Add to Supabase

3. ⏳ **swiftdash_paywithmaya (Pay with Maya)** - Need to create
   - Create application
   - Configure webhook URL
   - Get keys and webhook secret
   - Add to Supabase

### What's Already Done:

- ✅ Checkout API keys configured in Supabase
- ✅ All 3 webhook handlers deployed
- ✅ Database schema ready
- ✅ Edge functions for payment processing deployed

---

## Quick Reference

### Webhook URLs (Copy & Paste into Maya Portal)

**Checkout:**
```
https://lygzxmhskkqrntnmxtbb.supabase.co/functions/v1/maya-webhook
```

**Vault:**
```
https://lygzxmhskkqrntnmxtbb.supabase.co/functions/v1/maya-vault-webhook
```

**Pay with Maya:**
```
https://lygzxmhskkqrntnmxtbb.supabase.co/functions/v1/maya-paywithmaya-webhook
```

### Supabase Secret Commands

```powershell
# After getting webhook secrets from Maya, run:

# Checkout webhook secret
supabase secrets set MAYA_WEBHOOK_SECRET=whsec_YOUR_SECRET

# Vault keys and secret
supabase secrets set MAYA_VAULT_PUBLIC_KEY=pk-YOUR_KEY
supabase secrets set MAYA_VAULT_SECRET_KEY=sk-YOUR_KEY
supabase secrets set MAYA_VAULT_WEBHOOK_SECRET=whsec_YOUR_SECRET

# Pay with Maya keys and secret
supabase secrets set MAYA_PAYWITHMAYA_PUBLIC_KEY=pk-YOUR_KEY
supabase secrets set MAYA_PAYWITHMAYA_SECRET_KEY=sk-YOUR_KEY
supabase secrets set MAYA_PAYWITHMAYA_WEBHOOK_SECRET=whsec_YOUR_SECRET
```

---

## Troubleshooting

### Webhook Not Receiving Events

1. **Check webhook is registered:**
   - Login to Maya Portal
   - Check application → Settings → Webhooks
   - Verify URL is correct

2. **Check webhook secret is correct:**
   ```powershell
   supabase secrets list
   ```

3. **Test webhook manually:**
   - Maya Portal usually has a "Test Webhook" button
   - Click it to send a test event

4. **Check function logs:**
   ```powershell
   supabase functions logs maya-webhook --follow
   ```

### Signature Verification Failed

- Double-check webhook secret is correct
- Secret should start with `whsec_`
- Make sure no extra spaces in the secret

---

**Status:** ✅ Webhooks Deployed - Ready to Configure in Maya Portal

**Next:** Complete the configuration in Maya Developer Portal and add the secrets to Supabase

