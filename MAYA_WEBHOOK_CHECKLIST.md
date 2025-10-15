# Maya Webhook Setup - Simple Checklist

**Quick guide to complete webhook configuration**

---

## ✅ What's Already Done

- [x] 3 applications created in Maya Portal
- [x] All 6 API keys added to Supabase
- [x] 6 edge functions deployed and ready

---

## 📝 What You Need to Do (15 minutes)

### Webhook 1: swiftdash_sandbox (Checkout)

**Go to:** https://developers.maya.ph/  
**Select:** swiftdash_sandbox

```
1. Click: Settings → Webhooks → Add Webhook

2. Paste Webhook URL:
   https://lygzxmhskkqrntnmxtbb.supabase.co/functions/v1/maya-webhook

3. Select Events:
   ☑ AUTHORIZED
   ☑ CAPTURED
   ☑ VOIDED
   ☑ PAYMENT_FAILED
   ☑ PAYMENT_EXPIRED

4. Click: Create

5. Copy the webhook secret: whsec_xxxxx

6. In PowerShell, run:
   supabase secrets set MAYA_WEBHOOK_SECRET=whsec_YOUR_SECRET
```

**Status:** [ ] Done

---

### Webhook 2: swiftdash_vault_sandbox (Vault)

**Go to:** https://developers.maya.ph/  
**Select:** swiftdash_vault_sandbox

```
1. Click: Settings → Webhooks → Add Webhook

2. Paste Webhook URL:
   https://lygzxmhskkqrntnmxtbb.supabase.co/functions/v1/maya-vault-webhook

3. Select Events:
   ☑ PAYMENT_TOKEN_CREATED
   ☑ PAYMENT_TOKEN_UPDATED
   ☑ PAYMENT_TOKEN_DELETED

4. Click: Create

5. Copy the webhook secret: whsec_xxxxx

6. In PowerShell, run:
   supabase secrets set MAYA_VAULT_WEBHOOK_SECRET=whsec_YOUR_SECRET
```

**Status:** [ ] Done

---

### Webhook 3: swiftdash_paymaya_sandbox (Pay with Maya)

**Go to:** https://developers.maya.ph/  
**Select:** swiftdash_paymaya_sandbox

```
1. Click: Settings → Webhooks → Add Webhook

2. Paste Webhook URL:
   https://lygzxmhskkqrntnmxtbb.supabase.co/functions/v1/maya-paywithmaya-webhook

3. Select Events:
   ☑ PAYMENT_SUCCESS
   ☑ PAYMENT_FAILED
   ☑ PAYMENT_EXPIRED

4. Click: Create

5. Copy the webhook secret: whsec_xxxxx

6. In PowerShell, run:
   supabase secrets set MAYA_PAYWITHMAYA_WEBHOOK_SECRET=whsec_YOUR_SECRET
```

**Status:** [ ] Done

---

## ✅ Final Check

After completing all 3 webhooks, run:

```powershell
supabase secrets list
```

You should see 10 secrets total, including these 3 new ones:
- MAYA_WEBHOOK_SECRET
- MAYA_VAULT_WEBHOOK_SECRET
- MAYA_PAYWITHMAYA_WEBHOOK_SECRET

---

## 🎯 After Completion

Once all webhook secrets are added, we can:
1. Test the webhooks
2. Update the maya-webhook function
3. Start Flutter app integration

---

**Let me know when you've added the webhook secrets, and we'll test them!**

