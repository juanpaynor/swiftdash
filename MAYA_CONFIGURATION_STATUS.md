# Maya Applications - Configuration Status

**Date:** October 15, 2025  
**Time:** 2:00 PM UTC+8  
**Status:** 🟡 API Keys Configured - Webhook Secrets Needed

---

## ✅ Applications Created in Maya Portal

### 1. swiftdash_sandbox (Checkout)
**Status:** ✅ API Keys Configured

**API Keys:**
- Public Key: `pk-MYQ6WQ4dklZzGJlxjcEsKzlNGqTQJkrMLBGCAuduZlJ`
- Secret Key: `sk-j17xGgEM01WcuhoxHTxnWVPYTdGkGBrq79rujK4Agov`

**Supabase Secrets:**
- ✅ `MAYA_PUBLIC_KEY` - Configured
- ✅ `MAYA_SECRET_KEY` - Configured
- ⏳ `MAYA_WEBHOOK_SECRET` - **NEED TO GET FROM MAYA PORTAL**

**Webhook URL:**
```
https://lygzxmhskkqrntnmxtbb.supabase.co/functions/v1/maya-webhook
```

**Next Action:** Configure webhook in Maya Portal and get webhook secret

---

### 2. swiftdash_vault_sandbox (Vault)
**Status:** ✅ API Keys Configured

**API Keys:**
- Public Key: `pk-C65z1xX9DF1EN4DKISMQEwLDTCz4K6y7XtOBMgtbN5M`
- Secret Key: `sk-FUZXxOmarPjJDzq0HcRlUyMW6i2KVMO62XVjGK2tkQc`

**Supabase Secrets:**
- ✅ `MAYA_VAULT_PUBLIC_KEY` - Configured
- ✅ `MAYA_VAULT_SECRET_KEY` - Configured
- ⏳ `MAYA_VAULT_WEBHOOK_SECRET` - **NEED TO GET FROM MAYA PORTAL**

**Webhook URL:**
```
https://lygzxmhskkqrntnmxtbb.supabase.co/functions/v1/maya-vault-webhook
```

**Next Action:** Configure webhook in Maya Portal and get webhook secret

---

### 3. swiftdash_paymaya_sandbox (Pay with Maya)
**Status:** ✅ API Keys Configured

**API Keys:**
- Public Key: `pk-At8S5u4wtS9DDVABVP9dNLnLGFIjdLO27DFaaQzX5cZ`
- Secret Key: `sk-TkrpuXT5vCRYjvZhV7BDzooxTKwgBb3HvtucCnc83Iz`

**Supabase Secrets:**
- ✅ `MAYA_PAYWITHMAYA_PUBLIC_KEY` - Configured
- ✅ `MAYA_PAYWITHMAYA_SECRET_KEY` - Configured
- ⏳ `MAYA_PAYWITHMAYA_WEBHOOK_SECRET` - **NEED TO GET FROM MAYA PORTAL**

**Webhook URL:**
```
https://lygzxmhskkqrntnmxtbb.supabase.co/functions/v1/maya-paywithmaya-webhook
```

**Next Action:** Configure webhook in Maya Portal and get webhook secret

---

## 📋 Current Supabase Secrets Status

Run `supabase secrets list` to verify:

```
✅ MAYA_PUBLIC_KEY                   (Checkout public key)
✅ MAYA_SECRET_KEY                   (Checkout secret key)
⏳ MAYA_WEBHOOK_SECRET               (Need from Maya Portal)
✅ MAYA_VAULT_PUBLIC_KEY             (Vault public key)
✅ MAYA_VAULT_SECRET_KEY             (Vault secret key)
⏳ MAYA_VAULT_WEBHOOK_SECRET         (Need from Maya Portal)
✅ MAYA_PAYWITHMAYA_PUBLIC_KEY       (Pay with Maya public key)
✅ MAYA_PAYWITHMAYA_SECRET_KEY       (Pay with Maya secret key)
⏳ MAYA_PAYWITHMAYA_WEBHOOK_SECRET   (Need from Maya Portal)
✅ MAYA_ENVIRONMENT                  (sandbox)
```

**Progress:** 7/10 secrets configured (70%)

---

## 🎯 What You Need to Do Now

### Step 1: Configure Checkout Webhook (swiftdash_sandbox)

1. **Go to Maya Developer Portal:**
   - Login at: https://developers.maya.ph/
   - Select: **swiftdash_sandbox** application

2. **Navigate to Webhooks:**
   - Click: **Settings → Webhooks**
   - Click: **"Add Webhook"** or **"Configure Webhook"**

3. **Fill in Webhook Details:**
   ```
   Webhook URL:
   https://lygzxmhskkqrntnmxtbb.supabase.co/functions/v1/maya-webhook
   
   Description:
   SwiftDash Checkout Events
   
   Events to Subscribe:
   ☑ AUTHORIZED (or PAYMENT_AUTHORIZED)
   ☑ CAPTURED (or PAYMENT_CAPTURED)
   ☑ VOIDED (or PAYMENT_VOIDED)
   ☑ PAYMENT_FAILED
   ☑ PAYMENT_EXPIRED
   ```

4. **Get Webhook Secret:**
   - Click **"Create"** or **"Save"**
   - Maya will show: `whsec_xxxxxxxxxxxxxxxxx`
   - **COPY THIS - You can't see it again!**

5. **Add to Supabase:**
   ```powershell
   supabase secrets set MAYA_WEBHOOK_SECRET=whsec_YOUR_ACTUAL_SECRET
   ```

---

### Step 2: Configure Vault Webhook (swiftdash_vault_sandbox)

1. **Go to Maya Developer Portal:**
   - Select: **swiftdash_vault_sandbox** application

2. **Navigate to Webhooks:**
   - Click: **Settings → Webhooks**
   - Click: **"Add Webhook"**

3. **Fill in Webhook Details:**
   ```
   Webhook URL:
   https://lygzxmhskkqrntnmxtbb.supabase.co/functions/v1/maya-vault-webhook
   
   Description:
   SwiftDash Vault Events
   
   Events to Subscribe:
   ☑ PAYMENT_TOKEN_CREATED
   ☑ PAYMENT_TOKEN_UPDATED
   ☑ PAYMENT_TOKEN_DELETED
   ```

4. **Get Webhook Secret:**
   - Click **"Create"**
   - Copy: `whsec_xxxxxxxxxxxxxxxxx`

5. **Add to Supabase:**
   ```powershell
   supabase secrets set MAYA_VAULT_WEBHOOK_SECRET=whsec_YOUR_ACTUAL_SECRET
   ```

---

### Step 3: Configure Pay with Maya Webhook (swiftdash_paymaya_sandbox)

1. **Go to Maya Developer Portal:**
   - Select: **swiftdash_paymaya_sandbox** application

2. **Navigate to Webhooks:**
   - Click: **Settings → Webhooks**
   - Click: **"Add Webhook"**

3. **Fill in Webhook Details:**
   ```
   Webhook URL:
   https://lygzxmhskkqrntnmxtbb.supabase.co/functions/v1/maya-paywithmaya-webhook
   
   Description:
   SwiftDash Pay with Maya Events
   
   Events to Subscribe:
   ☑ PAYMENT_SUCCESS
   ☑ PAYMENT_FAILED
   ☑ PAYMENT_EXPIRED
   ```

4. **Get Webhook Secret:**
   - Click **"Create"**
   - Copy: `whsec_xxxxxxxxxxxxxxxxx`

5. **Add to Supabase:**
   ```powershell
   supabase secrets set MAYA_PAYWITHMAYA_WEBHOOK_SECRET=whsec_YOUR_ACTUAL_SECRET
   ```

---

## ✅ After All Webhooks Configured

### Final Verification

```powershell
# Check all secrets
supabase secrets list

# Should show 10 secrets total (including existing ones)
```

### Test Each Webhook

**Test Checkout:**
```powershell
# Trigger a test payment
curl -X POST `
  "https://lygzxmhskkqrntnmxtbb.supabase.co/functions/v1/create-maya-checkout" `
  -H "Authorization: Bearer YOUR_TOKEN" `
  -H "Content-Type: application/json" `
  -d '{"deliveryId":"test-001","amount":200,"paymentMethod":"creditCard","customerName":"Test User","customerPhone":"+639171234567"}'

# Check logs
supabase functions logs maya-webhook --limit 20
```

**Test Vault:**
```powershell
# Complete a payment with "Save this card" checked
# Then check logs
supabase functions logs maya-vault-webhook --limit 20
```

**Test Pay with Maya:**
```powershell
# Generate Maya Wallet QR code and pay
# Check logs
supabase functions logs maya-paywithmaya-webhook --limit 20
```

---

## 📊 Overall Progress

### Phase 1: Backend Infrastructure (95% Complete)

- [x] Database migration applied
- [x] Edge functions created
- [x] Edge functions deployed
- [x] API keys configured in Supabase
- [x] Webhook handlers deployed
- [ ] Webhook secrets configured (in progress)
- [ ] Webhooks tested

### Phase 2: Flutter App Integration (0% Complete)

- [ ] payment_service.dart refactored
- [ ] saved_cards_service.dart created
- [ ] maya_checkout_screen.dart created
- [ ] order_summary_screen.dart updated
- [ ] delivery.dart model updated

---

## 🎉 Summary

### ✅ What's Done:
- 3 applications created in Maya Portal
- 6 API keys configured in Supabase
- 6 edge functions deployed
- Database schema ready
- Test cards documented

### ⏳ What's Next (Now):
1. Configure webhook for **swiftdash_sandbox** → Get secret
2. Configure webhook for **swiftdash_vault_sandbox** → Get secret
3. Configure webhook for **swiftdash_paymaya_sandbox** → Get secret
4. Add all 3 webhook secrets to Supabase

**Estimated Time:** 10-15 minutes (3-5 minutes per webhook)

---

## 🆘 Quick Help

**Can't find webhook settings?**
- Look for "Settings" or "Configuration" in app dashboard
- Then "Webhooks" or "Webhook Configuration"

**Webhook secret not showing?**
- It only shows ONCE after creation
- If you missed it, delete webhook and create again

**Need to copy webhook URLs?**
- They're in this document above
- Or run: `supabase functions list`

---

**Status:** 🟡 Ready for Final Webhook Configuration

**Action Required:** Get 3 webhook secrets from Maya Portal and add to Supabase

**Last Updated:** October 15, 2025 @ 2:00 PM UTC+8

