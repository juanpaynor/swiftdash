# Maya Portal Setup - Visual Checklist

**Quick Reference Guide for Maya Developer Portal Configuration**

---

## 📱 Application 1: swiftdash_sandbox (Checkout)

**Status:** ✅ Already Created | ⏳ Needs Webhook Configuration

### Your Current Keys (Already in Supabase):
```
Public Key: pk-MYQ6WQ4dklZzGJlxjcEsKzlNGqTQJkrMLBGCAuduZlJ
Secret Key: sk-j17xGgEM01WcuhoxHTxnWVPYTdGkGBrq79rujK4Agov
```

### Webhook Configuration Steps:

```
┌─────────────────────────────────────────────────┐
│  Maya Developer Portal                          │
│  https://developers.maya.ph/                    │
└─────────────────────────────────────────────────┘
                    │
                    ▼
        ┌───────────────────────┐
        │  Login to Dashboard   │
        └───────────────────────┘
                    │
                    ▼
        ┌───────────────────────┐
        │ Select Application:   │
        │ "swiftdash_sandbox"   │
        └───────────────────────┘
                    │
                    ▼
        ┌───────────────────────┐
        │ Click "Settings"      │
        │ → "Webhooks"          │
        └───────────────────────┘
                    │
                    ▼
        ┌───────────────────────┐
        │ Click "Add Webhook"   │
        └───────────────────────┘
                    │
                    ▼
┌─────────────────────────────────────────────────┐
│  Webhook Configuration Form                     │
├─────────────────────────────────────────────────┤
│                                                 │
│  Webhook URL:                                   │
│  https://lygzxmhskkqrntnmxtbb.supabase.co/     │
│  functions/v1/maya-webhook                      │
│                                                 │
│  Description:                                   │
│  SwiftDash Checkout Events                      │
│                                                 │
│  Events to Subscribe:                           │
│  ☑ AUTHORIZED (or PAYMENT_AUTHORIZED)          │
│  ☑ CAPTURED (or PAYMENT_CAPTURED)              │
│  ☑ VOIDED (or PAYMENT_VOIDED)                  │
│  ☑ PAYMENT_FAILED                               │
│  ☑ PAYMENT_EXPIRED                              │
│                                                 │
│  [Create Webhook]                               │
└─────────────────────────────────────────────────┘
                    │
                    ▼
┌─────────────────────────────────────────────────┐
│  ⚠️  IMPORTANT: Copy Webhook Secret             │
├─────────────────────────────────────────────────┤
│                                                 │
│  Your Webhook Secret:                           │
│  whsec_abc123xyz456def789ghi012                 │
│                                                 │
│  ⚠️  Save this now - you can't see it again!    │
│                                                 │
│  [Copy to Clipboard]                            │
└─────────────────────────────────────────────────┘
                    │
                    ▼
        ┌───────────────────────┐
        │ Open PowerShell       │
        └───────────────────────┘
                    │
                    ▼
┌─────────────────────────────────────────────────┐
│  supabase secrets set MAYA_WEBHOOK_SECRET=\     │
│  whsec_YOUR_ACTUAL_SECRET_HERE                  │
└─────────────────────────────────────────────────┘
                    │
                    ▼
        ┌───────────────────────┐
        │ ✅ Checkout Complete! │
        └───────────────────────┘
```

---

## 💳 Application 2: swiftdash_vault (Vault)

**Status:** ⏳ Need to Create

### Creation Steps:

```
┌─────────────────────────────────────────────────┐
│  Maya Developer Portal Dashboard                │
└─────────────────────────────────────────────────┘
                    │
                    ▼
        ┌───────────────────────┐
        │ Click "Create         │
        │ Application"          │
        └───────────────────────┘
                    │
                    ▼
┌─────────────────────────────────────────────────┐
│  Application Details                            │
├─────────────────────────────────────────────────┤
│                                                 │
│  Application Name:                              │
│  swiftdash_vault                                │
│                                                 │
│  Description:                                   │
│  Card tokenization and vault for SwiftDash      │
│                                                 │
│  [Next]                                         │
└─────────────────────────────────────────────────┘
                    │
                    ▼
┌─────────────────────────────────────────────────┐
│  Configure Product                              │
├─────────────────────────────────────────────────┤
│                                                 │
│  Product Selected:                              │
│  ☑ Vault                                        │
│                                                 │
│  ─────────────────────────────────────────────  │
│                                                 │
│  Payment Methods:                               │
│  ☑ Visa (Default)                               │
│  ☑ Mastercard (Default)                         │
│  ☑ JCB (optional)                               │
│  ☐ QRPh                                         │
│                                                 │
│  ─────────────────────────────────────────────  │
│                                                 │
│  Integration:                                   │
│  ☑ API                                          │
│                                                 │
│  [Next]                                         │
└─────────────────────────────────────────────────┘
                    │
                    ▼
┌─────────────────────────────────────────────────┐
│  ⚠️  COPY THESE API KEYS                        │
├─────────────────────────────────────────────────┤
│                                                 │
│  Public Key:                                    │
│  pk-xxxxxxxxxxxxxxxxxxxxxxxxxx                  │
│  [Copy]                                         │
│                                                 │
│  Secret Key:                                    │
│  sk-xxxxxxxxxxxxxxxxxxxxxxxxxx                  │
│  [Copy]                                         │
│                                                 │
│  ⚠️  Save these - you'll need them!             │
│                                                 │
│  [Continue to Application]                      │
└─────────────────────────────────────────────────┘
                    │
                    ▼
        ┌───────────────────────┐
        │ Click "Settings"      │
        │ → "Webhooks"          │
        └───────────────────────┘
                    │
                    ▼
┌─────────────────────────────────────────────────┐
│  Webhook Configuration                          │
├─────────────────────────────────────────────────┤
│                                                 │
│  Webhook URL:                                   │
│  https://lygzxmhskkqrntnmxtbb.supabase.co/     │
│  functions/v1/maya-vault-webhook                │
│                                                 │
│  Description:                                   │
│  SwiftDash Vault Events                         │
│                                                 │
│  Events to Subscribe:                           │
│  ☑ PAYMENT_TOKEN_CREATED                        │
│  ☑ PAYMENT_TOKEN_UPDATED                        │
│  ☑ PAYMENT_TOKEN_DELETED                        │
│                                                 │
│  [Create Webhook]                               │
└─────────────────────────────────────────────────┘
                    │
                    ▼
┌─────────────────────────────────────────────────┐
│  ⚠️  Copy Webhook Secret                        │
├─────────────────────────────────────────────────┤
│                                                 │
│  whsec_xxxxxxxxxxxxxxxxxxxxxxxxxx               │
│  [Copy to Clipboard]                            │
│                                                 │
└─────────────────────────────────────────────────┘
                    │
                    ▼
        ┌───────────────────────┐
        │ Open PowerShell       │
        └───────────────────────┘
                    │
                    ▼
┌─────────────────────────────────────────────────┐
│  supabase secrets set \                         │
│    MAYA_VAULT_PUBLIC_KEY=pk-YOUR_KEY \          │
│    MAYA_VAULT_SECRET_KEY=sk-YOUR_KEY \          │
│    MAYA_VAULT_WEBHOOK_SECRET=whsec_YOUR_SECRET  │
└─────────────────────────────────────────────────┘
                    │
                    ▼
        ┌───────────────────────┐
        │ ✅ Vault Complete!    │
        └───────────────────────┘
```

---

## 💰 Application 3: swiftdash_paywithmaya (Pay with Maya)

**Status:** ⏳ Need to Create

### Creation Steps:

```
┌─────────────────────────────────────────────────┐
│  Maya Developer Portal Dashboard                │
└─────────────────────────────────────────────────┘
                    │
                    ▼
        ┌───────────────────────┐
        │ Click "Create         │
        │ Application"          │
        └───────────────────────┘
                    │
                    ▼
┌─────────────────────────────────────────────────┐
│  Application Details                            │
├─────────────────────────────────────────────────┤
│                                                 │
│  Application Name:                              │
│  swiftdash_paywithmaya                          │
│                                                 │
│  Description:                                   │
│  Maya Wallet payments for SwiftDash             │
│                                                 │
│  [Next]                                         │
└─────────────────────────────────────────────────┘
                    │
                    ▼
┌─────────────────────────────────────────────────┐
│  Configure Product                              │
├─────────────────────────────────────────────────┤
│                                                 │
│  Product Selected:                              │
│  ☑ Pay with Maya                                │
│                                                 │
│  ─────────────────────────────────────────────  │
│                                                 │
│  Integration:                                   │
│  ☑ API                                          │
│                                                 │
│  [Next]                                         │
└─────────────────────────────────────────────────┘
                    │
                    ▼
┌─────────────────────────────────────────────────┐
│  ⚠️  COPY THESE API KEYS                        │
├─────────────────────────────────────────────────┤
│                                                 │
│  Public Key:                                    │
│  pk-xxxxxxxxxxxxxxxxxxxxxxxxxx                  │
│  [Copy]                                         │
│                                                 │
│  Secret Key:                                    │
│  sk-xxxxxxxxxxxxxxxxxxxxxxxxxx                  │
│  [Copy]                                         │
│                                                 │
│  ⚠️  Save these - you'll need them!             │
│                                                 │
│  [Continue to Application]                      │
└─────────────────────────────────────────────────┘
                    │
                    ▼
        ┌───────────────────────┐
        │ Click "Settings"      │
        │ → "Webhooks"          │
        └───────────────────────┘
                    │
                    ▼
┌─────────────────────────────────────────────────┐
│  Webhook Configuration                          │
├─────────────────────────────────────────────────┤
│                                                 │
│  Webhook URL:                                   │
│  https://lygzxmhskkqrntnmxtbb.supabase.co/     │
│  functions/v1/maya-paywithmaya-webhook          │
│                                                 │
│  Description:                                   │
│  SwiftDash Pay with Maya Events                 │
│                                                 │
│  Events to Subscribe:                           │
│  ☑ PAYMENT_SUCCESS                              │
│  ☑ PAYMENT_FAILED                               │
│  ☑ PAYMENT_EXPIRED                              │
│                                                 │
│  [Create Webhook]                               │
└─────────────────────────────────────────────────┘
                    │
                    ▼
┌─────────────────────────────────────────────────┐
│  ⚠️  Copy Webhook Secret                        │
├─────────────────────────────────────────────────┤
│                                                 │
│  whsec_xxxxxxxxxxxxxxxxxxxxxxxxxx               │
│  [Copy to Clipboard]                            │
│                                                 │
└─────────────────────────────────────────────────┘
                    │
                    ▼
        ┌───────────────────────┐
        │ Open PowerShell       │
        └───────────────────────┘
                    │
                    ▼
┌─────────────────────────────────────────────────┐
│  supabase secrets set \                         │
│    MAYA_PAYWITHMAYA_PUBLIC_KEY=pk-YOUR_KEY \    │
│    MAYA_PAYWITHMAYA_SECRET_KEY=sk-YOUR_KEY \    │
│    MAYA_PAYWITHMAYA_WEBHOOK_SECRET=\            │
│    whsec_YOUR_SECRET                            │
└─────────────────────────────────────────────────┘
                    │
                    ▼
        ┌───────────────────────┐
        │ ✅ Pay with Maya      │
        │    Complete!          │
        └───────────────────────┘
```

---

## ✅ Final Verification

After completing all 3 applications, verify all secrets:

```powershell
supabase secrets list
```

**You should see 9 secrets:**

```
┌────────────────────────────────┬──────────────────────────────┐
│ NAME                           │ STATUS                       │
├────────────────────────────────┼──────────────────────────────┤
│ MAYA_PUBLIC_KEY                │ ✅ Set (Checkout)            │
│ MAYA_SECRET_KEY                │ ✅ Set (Checkout)            │
│ MAYA_WEBHOOK_SECRET            │ ✅ Set (Checkout)            │
│ MAYA_VAULT_PUBLIC_KEY          │ ✅ Set (Vault)               │
│ MAYA_VAULT_SECRET_KEY          │ ✅ Set (Vault)               │
│ MAYA_VAULT_WEBHOOK_SECRET      │ ✅ Set (Vault)               │
│ MAYA_PAYWITHMAYA_PUBLIC_KEY    │ ✅ Set (Pay with Maya)       │
│ MAYA_PAYWITHMAYA_SECRET_KEY    │ ✅ Set (Pay with Maya)       │
│ MAYA_PAYWITHMAYA_WEBHOOK_SECRET│ ✅ Set (Pay with Maya)       │
└────────────────────────────────┴──────────────────────────────┘
```

---

## 🧪 Test Each Webhook

### Test 1: Checkout Webhook
```powershell
# Trigger test payment
curl -X POST `
  "https://lygzxmhskkqrntnmxtbb.supabase.co/functions/v1/create-maya-checkout" `
  -H "Authorization: Bearer YOUR_TOKEN" `
  -H "Content-Type: application/json" `
  -d '{"deliveryId":"test-001","amount":200,"paymentMethod":"creditCard","customerName":"Test User","customerPhone":"+639171234567"}'

# Check logs
supabase functions logs maya-webhook --limit 10
```

### Test 2: Vault Webhook
```powershell
# Complete checkout with "Save this card" checked
# Then check logs
supabase functions logs maya-vault-webhook --limit 10

# Verify card saved
# Check database: customer_payment_methods table
```

### Test 3: Pay with Maya Webhook
```powershell
# Generate Maya Wallet QR code
# Scan and pay with Maya app
# Check logs
supabase functions logs maya-paywithmaya-webhook --limit 10
```

---

## 📋 Progress Tracker

```
Application Setup Progress:
─────────────────────────────────────────────────────────
[x] Application 1: swiftdash_sandbox (Checkout)
    [x] Application created
    [x] API keys configured in Supabase
    [ ] Webhook configured in Maya Portal
    [ ] Webhook secret added to Supabase

[ ] Application 2: swiftdash_vault (Vault)
    [ ] Application created in Maya Portal
    [ ] API keys copied
    [ ] API keys added to Supabase
    [ ] Webhook configured in Maya Portal
    [ ] Webhook secret added to Supabase

[ ] Application 3: swiftdash_paywithmaya (Pay with Maya)
    [ ] Application created in Maya Portal
    [ ] API keys copied
    [ ] API keys added to Supabase
    [ ] Webhook configured in Maya Portal
    [ ] Webhook secret added to Supabase

Webhook Handlers:
─────────────────────────────────────────────────────────
[x] maya-webhook deployed
[x] maya-vault-webhook deployed
[x] maya-paywithmaya-webhook deployed
```

---

## 🆘 Need Help?

**Can't find "Create Application"?**
- Look for "+ New Application" or "Add Application" button
- Usually in top-right corner of dashboard

**Don't see webhook events in dropdown?**
- Different products have different events
- If you don't see exact names, use closest match
- Common alternatives:
  - AUTHORIZED = PAYMENT_AUTHORIZED
  - CAPTURED = PAYMENT_CAPTURED

**Webhook secret not showing?**
- After creating webhook, Maya shows secret ONCE
- If you missed it, delete webhook and create new one
- Can't retrieve secret later, must recreate

**Error when adding secrets to Supabase?**
- Make sure you're in correct project: lygzxmhskkqrntnmxtbb
- Check for typos in secret names
- Secrets are case-sensitive

---

**Ready to configure? Start with Application 1 (swiftdash_sandbox) webhook!**

