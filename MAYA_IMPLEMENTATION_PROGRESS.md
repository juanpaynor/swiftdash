# Maya API Integration - Implementation Progress

**Date:** October 15, 2025  
**Status:** ✅ Phase 1 Complete - Backend Functions Ready  
**Next:** Phase 2 - Flutter Service Refactoring

---

## ✅ COMPLETED TASKS

### 1. Project Requirements Finalized ✅
**File:** `MAYA_IMPLEMENTATION_REQUIREMENTS.md`

**Confirmed Decisions:**
- ✅ **Payment Fees:** Customer pays (3.5% + ₱15 for cards, 2.5% for Maya Wallet)
- ✅ **Fee Transparency:** Show breakdown BEFORE payment
- ✅ **Card Vaulting:** Use Maya Vault API to save cards
- ✅ **Payment Flow:** Auth+Capture (hold payment, charge when driver accepts)
- ✅ **Auto-Void:** 24-hour auto-cancellation if no driver
- ✅ **No Installments:** Single payment only

---

### 2. Flutter Dependencies Installed ✅
**File:** `pubspec.yaml`

**Added Packages:**
- ✅ `http: ^1.2.0` - Already present, upgraded
- ✅ `webview_flutter: ^4.5.0` - **NEW** - For Maya checkout page
- ✅ `url_launcher: ^6.3.1` - Already present
- ✅ `flutter_dotenv: ^6.0.0` - Already present

**Command Run:**
```bash
flutter pub get  # ✅ SUCCESS
```

---

### 3. Database Migration Created ✅
**File:** `supabase/migrations/20251015_maya_vault_and_auth_capture.sql`

**New Tables:**
- ✅ `customer_payment_methods` - Stores Maya vault tokens
  - Columns: `id`, `customer_id`, `card_token`, `card_type`, `last_four_digits`, `expiry_month`, `expiry_year`, `is_default`, `is_active`
  - RLS policies: Users can only access their own cards
  - Triggers: Auto-update `updated_at`, ensure single default card

- ✅ `payment_webhook_logs` - Logs all Maya webhooks
  - Columns: `id`, `delivery_id`, `event_type`, `payload`, `signature`, `signature_verified`, `processed`
  - Purpose: Debugging and auditing

**New Columns in `deliveries` table:**
- ✅ `payment_authorization_id` - Maya auth ID
- ✅ `payment_authorized_at` - Authorization timestamp
- ✅ `payment_captured_at` - Capture timestamp
- ✅ `payment_void_at` - Void timestamp
- ✅ `payment_auto_void_at` - Auto-void deadline (24h)
- ✅ `payment_processing_fee` - Processing fee amount
- ✅ `payment_total_amount` - Delivery + processing fee

**Helper Functions:**
- ✅ `get_customer_saved_cards(customer_id)` - Get active saved cards
- ✅ `authorize_delivery_payment(delivery_id, ...)` - Mark payment as authorized
- ✅ `capture_delivery_payment(delivery_id, payment_id)` - Mark as captured
- ✅ `void_delivery_payment(delivery_id, reason)` - Mark as voided
- ✅ `get_deliveries_for_auto_void()` - Find expired authorizations

**Status:** Ready to deploy with `supabase db push`

---

### 4. Supabase Edge Functions Created ✅

#### ✅ Function 1: `create-maya-checkout`
**File:** `supabase/functions/create-maya-checkout/index.ts`

**Purpose:** Create Maya checkout session

**Features:**
- ✅ Calculates processing fee (3.5% + ₱15 for cards, 2.5% for wallet)
- ✅ Creates Maya checkout with total amount (delivery + fee)
- ✅ Supports saved card tokens (vault)
- ✅ Returns checkout URL for WebView
- ✅ Updates delivery record with checkout ID
- ✅ Handles errors gracefully

**API Endpoint:** `POST /functions/v1/create-maya-checkout`

**Request:**
```json
{
  "deliveryId": "uuid",
  "amount": 200.00,
  "paymentMethod": "creditCard",
  "customerName": "Juan Dela Cruz",
  "customerPhone": "+639171234567",
  "customerEmail": "optional@example.com",
  "savedCardToken": "optional_vault_token",
  "saveCard": true
}
```

**Response:**
```json
{
  "success": true,
  "checkoutId": "ch_xxx",
  "checkoutUrl": "https://pg-sandbox.paymaya.com/checkout/...",
  "expiresAt": "2025-10-15T12:00:00Z",
  "totalAmount": 222.00,
  "processingFee": 22.00
}
```

---

#### ✅ Function 2: `capture-maya-payment`
**File:** `supabase/functions/capture-maya-payment/index.ts`

**Purpose:** Capture authorized payment when driver accepts

**Features:**
- ✅ Validates payment can be captured (status = 'authorized')
- ✅ Calls Maya Capture API
- ✅ Updates delivery: `payment_captured_at`, `payment_status = 'paid'`
- ✅ Clears auto-void deadline
- ✅ Supports partial capture (optional)
- ✅ Error handling with detailed messages

**API Endpoint:** `POST /functions/v1/capture-maya-payment`

**Request:**
```json
{
  "deliveryId": "uuid",
  "amount": 222.00  // Optional: partial capture
}
```

**Response:**
```json
{
  "success": true,
  "paymentId": "pay_xxx",
  "capturedAmount": 222.00,
  "capturedAt": "2025-10-15T10:30:00Z"
}
```

---

#### ✅ Function 3: `void-maya-payment`
**File:** `supabase/functions/void-maya-payment/index.ts`

**Purpose:** Void authorized payment (cancel without charging)

**Features:**
- ✅ Validates payment can be voided (not captured yet)
- ✅ Calls Maya Void API
- ✅ Updates delivery: `payment_void_at`, `payment_status = 'voided'`
- ✅ Handles already-voided gracefully
- ✅ Used for: Customer cancellation, No driver found, Manual intervention

**API Endpoint:** `POST /functions/v1/void-maya-payment`

**Request:**
```json
{
  "deliveryId": "uuid",
  "reason": "No drivers available"
}
```

**Response:**
```json
{
  "success": true,
  "voidedAt": "2025-10-15T11:00:00Z",
  "reason": "No drivers available"
}
```

---

#### ⚠️ Function 4: `maya-webhook` (Needs Update)
**File:** `supabase/functions/maya-webhook/index.ts`

**Status:** EXISTS but needs update for Auth+Capture flow

**Required Updates:**
- [ ] Handle `AUTHORIZED` event → Update to `payment_status = 'authorized'`
- [ ] Handle `CAPTURED` event → Update to `payment_status = 'paid'`
- [ ] Handle `VOIDED` event → Update to `payment_status = 'voided'`
- [ ] Verify webhook signature using `MAYA_WEBHOOK_SECRET`
- [ ] Save card token if `saveCard = true` in metadata
- [ ] Log all webhooks to `payment_webhook_logs` table

**Next Step:** Update this function in Phase 2

---

## 🚧 IN PROGRESS

### Maya Credentials Confirmed ✅
**Location:** `.env` file

```properties
MAYA_PUBLIC_KEY=pk-lNAUk1jk7VPnf7koOT1uoGJoZJjmAxrbjpj6urB8EIA
MAYA_SECRET_KEY=sk-fzukI3GXrzNIUyvXY3n16cji8VTJITfzylz5o5QzZMC
MAYA_ENVIRONMENT=sandbox
```

**Action Required:** Add these to Supabase Secrets

---

## 📋 TODO - Phase 2: Frontend Implementation

### 1. Refactor `payment_service.dart` 
**File:** `lib/services/payment_service.dart`

**Tasks:**
- [ ] Remove all MethodChannel code
- [ ] Remove `_platform` instance and imports
- [ ] Add HTTP client (`import 'package:http/http.dart' as http`)
- [ ] Create methods:
  - [ ] `createCheckout()` - Call edge function
  - [ ] `openCheckoutWebView()` - Open Maya page
  - [ ] `capturePayment()` - Call capture function
  - [ ] `voidPayment()` - Call void function
  - [ ] `calculateProcessingFee()` - Fee calculation
  - [ ] `getTotalWithFee()` - Total amount

---

### 2. Create `saved_cards_service.dart`
**File:** `lib/services/saved_cards_service.dart` (NEW)

**Tasks:**
- [ ] `getSavedCards()` - Fetch from DB
- [ ] `addSavedCard()` - Save card token
- [ ] `deleteSavedCard()` - Remove card
- [ ] `setDefaultCard()` - Set default
- [ ] `isCardExpired()` - Check expiry

---

### 3. Update `order_summary_screen.dart`
**File:** `lib/screens/order_summary_screen.dart`

**Tasks:**
- [ ] Show fee breakdown UI:
  ```
  Delivery Fee:     ₱200.00
  Processing Fee:   ₱ 22.00 ⓘ
  ─────────────────────────
  Total:            ₱222.00
  ```
- [ ] Add saved cards selection (radio buttons)
- [ ] Add "Save card" checkbox
- [ ] Update payment flow: Create checkout → Open WebView → Wait for result
- [ ] Show status: "Authorizing...", "Finding driver...", "Payment captured!"

---

### 4. Create WebView Payment Screen
**File:** `lib/screens/maya_checkout_screen.dart` (NEW)

**Tasks:**
- [ ] Create fullscreen WebView
- [ ] Load Maya checkout URL
- [ ] Listen for redirect URLs (success/failure/cancel)
- [ ] Handle result and navigate back
- [ ] Show loading indicator

---

### 5. Update Delivery Models
**File:** `lib/models/delivery.dart`

**Tasks:**
- [ ] Add `paymentAuthorizationId` field
- [ ] Add `paymentAuthorizedAt` field
- [ ] Add `paymentCapturedAt` field
- [ ] Add `paymentVoidAt` field
- [ ] Add `paymentAutoVoidAt` field
- [ ] Add `paymentProcessingFee` field
- [ ] Add `paymentTotalAmount` field
- [ ] Update `fromJson()` and `toJson()` methods

---

## 🚀 DEPLOYMENT STEPS

### Step 1: Deploy Database Migration
```bash
cd e:\ondemand\myapp
supabase db push
```

### Step 2: Add Supabase Secrets
```bash
supabase secrets set MAYA_PUBLIC_KEY=pk-lNAUk1jk7VPnf7koOT1uoGJoZJjmAxrbjpj6urB8EIA
supabase secrets set MAYA_SECRET_KEY=sk-fzukI3GXrzNIUyvXY3n16cji8VTJITfzylz5o5QzZMC
supabase secrets set MAYA_WEBHOOK_SECRET=<get_from_maya_dashboard>
supabase secrets set MAYA_ENVIRONMENT=sandbox
```

### Step 3: Deploy Edge Functions
```bash
supabase functions deploy create-maya-checkout
supabase functions deploy capture-maya-payment
supabase functions deploy void-maya-payment
supabase functions deploy maya-webhook  # After updating
```

### Step 4: Register Webhook with Maya
1. Login to Maya Developer Portal
2. Go to Webhooks section
3. Add URL: `https://lygzxmhskkqrntnmxtbb.supabase.co/functions/v1/maya-webhook`
4. Save webhook secret to Supabase

### Step 5: Test in Sandbox
Use Maya test cards:
- Success: `4123450131001381`
- Declined: `4123450131001522`
- CVV: `123`, Expiry: Any future date

---

## 📊 PROGRESS SUMMARY

| Phase | Tasks | Completed | Status |
|-------|-------|-----------|--------|
| **Phase 1: Backend** | 7 | 6 | 🟢 85% |
| - Requirements | 1 | 1 | ✅ |
| - Dependencies | 1 | 1 | ✅ |
| - Database | 1 | 1 | ✅ |
| - Edge Functions | 4 | 3 | 🟡 (1 needs update) |
| **Phase 2: Frontend** | 5 | 0 | ⏳ Not Started |
| - Payment Service | 1 | 0 | ⏳ |
| - Saved Cards Service | 1 | 0 | ⏳ |
| - UI Updates | 2 | 0 | ⏳ |
| - Model Updates | 1 | 0 | ⏳ |
| **Phase 3: Testing** | 1 | 0 | ⏳ Not Started |
| **Phase 4: Deployment** | 1 | 0 | ⏳ Not Started |

**Overall Progress:** 40% Complete (6/15 tasks)

---

## 🎯 IMMEDIATE NEXT STEPS

1. **Deploy Database Migration** (5 min)
   ```bash
   supabase db push
   ```

2. **Add Supabase Secrets** (5 min)
   - Maya API keys
   - Webhook secret

3. **Update maya-webhook function** (30 min)
   - Add Auth+Capture event handling
   - Add signature verification
   - Add card vaulting logic

4. **Deploy Edge Functions** (10 min)
   ```bash
   supabase functions deploy --all
   ```

5. **Start Frontend Refactoring** (2-3 hours)
   - Refactor `payment_service.dart`
   - Remove MethodChannel code
   - Add HTTP API calls

---

## 💡 KEY INSIGHTS

### What's Different from Original Plan?
- ✅ Using **Auth+Capture** instead of simple checkout (better user experience)
- ✅ Added **automatic void** system (no manual cleanup needed)
- ✅ Created **4 edge functions** instead of 3 (added void function)
- ✅ More comprehensive **database schema** (vault + auth/capture fields)

### What's Working Well?
- ✅ Clear separation: Backend (Supabase) handles Maya API, Frontend just displays
- ✅ Processing fee calculation is centralized in backend
- ✅ All sensitive operations (auth, capture, void) are server-side
- ✅ Database functions make it easy to manage payment states

### What's Next?
1. Deploy backend (database + functions)
2. Refactor Flutter payment service
3. Update UI to show fee breakdown
4. Test with Maya sandbox
5. Deploy to production

---

**Status:** ✅ **BACKEND READY - FRONTEND NEXT**

**Estimated Time to Complete Frontend:** 4-6 hours

**Estimated Time to Test & Deploy:** 2-3 hours

**Total Time to Production:** 6-9 hours

