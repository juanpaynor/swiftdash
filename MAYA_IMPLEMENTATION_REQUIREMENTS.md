# Maya API Implementation Requirements

**Date:** October 15, 2025  
**Status:** ✅ APPROVED - Implementation Starting

---

## Confirmed Requirements

### 1. Payment Processing Fees ✅
**Decision:** Customer pays the processing fees

**Maya Fee Structure:**
- Credit/Debit Cards: **3.5% + ₱15** per transaction
- Maya Wallet: **2.5%** per transaction

**Implementation:**
- Show fee breakdown BEFORE payment
- Display: `Delivery: ₱200 + Processing Fee: ₱22 = Total: ₱222`
- Make it transparent and clear in UI

**Example Calculation:**
```dart
double calculateProcessingFee(double amount, PaymentMethod method) {
  if (method == PaymentMethod.creditCard) {
    return (amount * 0.035) + 15; // 3.5% + ₱15
  } else if (method == PaymentMethod.mayaWallet) {
    return amount * 0.025; // 2.5%
  }
  return 0; // Cash has no processing fee
}
```

---

### 2. Maya Vault API - Save Payment Methods ✅
**Decision:** Implement card vaulting for returning customers

**How Maya Vault Works:**
1. Customer enters card details once
2. Maya tokenizes the card → Returns `cardToken`
3. Store token in your database (NOT the card number)
4. Future payments: Use token instead of asking for card again

**Benefits:**
- Faster checkout for repeat customers
- Better conversion rate
- Secure (PCI-DSS compliant)

**API Endpoints:**
- **Create Vault:** `POST /payments/v1/payment-tokens`
- **Use Vault:** Include `paymentTokenId` in checkout request
- **Delete Vault:** `DELETE /payments/v1/payment-tokens/{tokenId}`

**Database Schema Addition:**
```sql
-- New table for saved cards
CREATE TABLE customer_payment_methods (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  customer_id UUID REFERENCES auth.users(id) NOT NULL,
  card_token TEXT NOT NULL,           -- Maya vault token
  card_type TEXT,                      -- VISA, MASTERCARD, JCB
  last_four_digits TEXT,               -- For display: "•••• 1234"
  expiry_month INTEGER,
  expiry_year INTEGER,
  is_default BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  
  CONSTRAINT unique_customer_card UNIQUE(customer_id, card_token)
);

-- RLS policies
ALTER TABLE customer_payment_methods ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own payment methods"
  ON customer_payment_methods FOR SELECT
  USING (auth.uid() = customer_id);

CREATE POLICY "Users can insert own payment methods"
  ON customer_payment_methods FOR INSERT
  WITH CHECK (auth.uid() = customer_id);

CREATE POLICY "Users can delete own payment methods"
  ON customer_payment_methods FOR DELETE
  USING (auth.uid() = customer_id);
```

**UI Flow:**
1. **New customer:** "Save this card for faster checkout next time?" [✓]
2. **Returning customer:** Shows saved cards → "•••• 1234 (Visa)" → Select and pay
3. **Manage cards:** Settings screen to add/remove saved cards

---

### 3. Payment Authorization + Capture ✅
**Decision:** Use Auth+Capture flow (payment hold)

**Why This Matters:**
- **Problem:** Customer pays upfront → Delivery fails → Refund hassle
- **Solution:** Authorize (hold) payment → Capture only when driver accepts

**How It Works:**

```
┌──────────────────┐
│ Customer Books   │
│ Delivery         │
└────────┬─────────┘
         │
         │ 1. Authorize Payment (Hold ₱222)
         ▼
┌──────────────────┐
│ Maya API:        │
│ Authorization    │
│ Status: PENDING  │
└────────┬─────────┘
         │
         │ 2. Find Driver
         ▼
┌──────────────────┐
│ Driver Accepts   │
│ Delivery         │
└────────┬─────────┘
         │
         │ 3. Capture Payment (Charge ₱222)
         ▼
┌──────────────────┐
│ Maya API:        │
│ Capture Payment  │
│ Status: PAID     │
└──────────────────┘
```

**Benefits:**
- ✅ Customer sees charge immediately (not "pending" limbo)
- ✅ No driver = Auto-void after 24h → Customer NOT charged
- ✅ Less refunds = Less customer support
- ✅ Better cash flow management

**Maya API Endpoints:**
- **Authorize:** `POST /payments/v1/payment-rrns` with `"capture": false`
- **Capture:** `POST /payments/v1/payment-rrns/{id}/capture`
- **Void:** `POST /payments/v1/payment-rrns/{id}/void`

**Database Schema Update:**
```sql
-- Add to deliveries table
ALTER TABLE deliveries ADD COLUMN payment_authorization_id TEXT;
ALTER TABLE deliveries ADD COLUMN payment_authorized_at TIMESTAMPTZ;
ALTER TABLE deliveries ADD COLUMN payment_captured_at TIMESTAMPTZ;
ALTER TABLE deliveries ADD COLUMN payment_void_at TIMESTAMPTZ;
ALTER TABLE deliveries ADD COLUMN payment_auto_void_at TIMESTAMPTZ; -- 24h from auth
```

**Business Logic:**
```typescript
// When customer books delivery
const authResult = await authorizePayment({
  amount: totalAmount,
  cardToken: savedCardToken,
  capture: false, // IMPORTANT: Don't capture yet
});

// Store authorization ID
await updateDelivery(deliveryId, {
  payment_authorization_id: authResult.id,
  payment_authorized_at: new Date(),
  payment_auto_void_at: new Date(Date.now() + 24 * 60 * 60 * 1000), // +24h
});

// When driver accepts
const captureResult = await capturePayment({
  authorizationId: delivery.payment_authorization_id,
  amount: delivery.total_price,
});

// When no driver found (background job)
if (delivery.payment_auto_void_at < new Date() && delivery.status === 'pending') {
  await voidPayment(delivery.payment_authorization_id);
  await cancelDelivery(deliveryId);
}
```

**Auto-Void System:**
- Background cron job runs every 5 minutes
- Checks for deliveries with `payment_authorized_at` > 24h and status = 'pending'
- Automatically voids authorization
- Notifies customer: "No drivers available, payment authorization cancelled"

---

### 4. No Installment Payments ❌
**Decision:** Do NOT implement installment payments

**Reasoning:**
- Delivery fees are small (₱100-500)
- Installments add complexity (3, 6, 12 months)
- Target customers prefer one-time payment
- Simpler = Better UX

**Implementation:**
- Simply don't enable installment options in Maya checkout
- Keep checkout flow simple and fast

---

## Updated Implementation Phases

### Phase 1: Setup & Dependencies (Day 1) ✅
**Status:** Starting now

**Tasks:**
1. ✅ Maya credentials confirmed in `.env`
2. Add Flutter packages: `http`, `webview_flutter`, `url_launcher`, `flutter_dotenv`
3. Add Supabase secrets: `MAYA_PUBLIC_KEY`, `MAYA_SECRET_KEY`, `MAYA_WEBHOOK_SECRET`
4. Create database migration for vault + auth/capture fields

---

### Phase 2: Backend - Edge Functions (Days 2-4)

**Function 1: `create-maya-checkout`**
- Create checkout with `"capture": false` (authorization only)
- Calculate and include processing fee
- Support card token from vault
- Return checkout URL

**Function 2: `maya-webhook`**
- Handle `AUTHORIZED`, `CAPTURED`, `VOIDED`, `FAILED` events
- Verify webhook signature
- Update delivery payment status

**Function 3: `capture-maya-payment`**
- Called when driver accepts delivery
- Captures authorized payment
- Updates `payment_captured_at` timestamp

**Function 4: `void-maya-payment`**
- Called when delivery cancelled or expired
- Voids authorization (customer not charged)
- Updates `payment_void_at` timestamp

**Function 5: `maya-vault-card`**
- Create payment token for card vaulting
- Return token + card metadata (last 4, type)
- Store in `customer_payment_methods` table

**Function 6: `auto-void-expired-authorizations`**
- Cron job (runs every 5 minutes)
- Finds expired authorizations (>24h, status=pending)
- Voids them automatically
- Notifies customers

---

### Phase 3: Frontend - Payment Service (Days 5-6)

**Refactor `payment_service.dart`:**
- Remove all MethodChannel code
- Add HTTP client
- Implement:
  - `createCheckout()` - With auth+capture flag
  - `vaultCard()` - Save payment method
  - `getSavedCards()` - List saved cards
  - `deleteSavedCard()` - Remove card
  - `calculateProcessingFee()` - Fee calculation
  - `getTotalWithFee()` - Delivery + Fee

**Create `saved_cards_service.dart`:**
- CRUD operations for saved payment methods
- Default card management
- Card expiry validation

---

### Phase 4: UI Updates (Days 7-8)

**OrderSummaryScreen Changes:**
```dart
// Show fee breakdown
Row(
  children: [
    Text('Delivery Fee:'),
    Spacer(),
    Text('₱${deliveryFee.toStringAsFixed(2)}'),
  ],
),
Row(
  children: [
    Text('Processing Fee:'),
    Tooltip(
      message: 'Credit card processing fee (3.5% + ₱15)',
      child: Icon(Icons.info_outline),
    ),
    Spacer(),
    Text('₱${processingFee.toStringAsFixed(2)}'),
  ],
),
Divider(),
Row(
  children: [
    Text('Total:', style: TextStyle(fontWeight: FontWeight.bold)),
    Spacer(),
    Text('₱${totalAmount.toStringAsFixed(2)}', style: TextStyle(fontWeight: FontWeight.bold)),
  ],
),
```

**Saved Cards UI:**
- Radio buttons to select saved card
- "Add new card" option
- Checkbox: "Save this card for future use"
- Settings → Payment Methods → Manage saved cards

**Payment Status Messages:**
- "Authorizing payment..." (during auth)
- "Payment authorized - Finding driver..." (after auth)
- "Payment captured - Delivery confirmed!" (after capture)
- "Payment authorization cancelled - No drivers available" (after void)

---

### Phase 5: Database Migration (Day 9)

**Create migration file:**
```sql
-- File: supabase/migrations/20251015_maya_vault_and_auth_capture.sql

-- Table for saved payment methods
CREATE TABLE customer_payment_methods (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  customer_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  card_token TEXT NOT NULL,
  card_type TEXT,
  last_four_digits TEXT,
  expiry_month INTEGER,
  expiry_year INTEGER,
  is_default BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  
  CONSTRAINT unique_customer_card UNIQUE(customer_id, card_token)
);

-- Add auth/capture fields to deliveries
ALTER TABLE deliveries ADD COLUMN IF NOT EXISTS payment_authorization_id TEXT;
ALTER TABLE deliveries ADD COLUMN IF NOT EXISTS payment_authorized_at TIMESTAMPTZ;
ALTER TABLE deliveries ADD COLUMN IF NOT EXISTS payment_captured_at TIMESTAMPTZ;
ALTER TABLE deliveries ADD COLUMN IF NOT EXISTS payment_void_at TIMESTAMPTZ;
ALTER TABLE deliveries ADD COLUMN IF NOT EXISTS payment_auto_void_at TIMESTAMPTZ;

-- RLS policies
ALTER TABLE customer_payment_methods ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own payment methods"
  ON customer_payment_methods FOR SELECT
  USING (auth.uid() = customer_id);

CREATE POLICY "Users can insert own payment methods"
  ON customer_payment_methods FOR INSERT
  WITH CHECK (auth.uid() = customer_id);

CREATE POLICY "Users can delete own payment methods"
  ON customer_payment_methods FOR DELETE
  USING (auth.uid() = customer_id);

CREATE POLICY "Users can update own payment methods"
  ON customer_payment_methods FOR UPDATE
  USING (auth.uid() = customer_id);

-- Index for performance
CREATE INDEX idx_customer_payment_methods_customer ON customer_payment_methods(customer_id);
CREATE INDEX idx_deliveries_payment_authorization ON deliveries(payment_authorization_id) WHERE payment_authorization_id IS NOT NULL;
CREATE INDEX idx_deliveries_auto_void ON deliveries(payment_auto_void_at) WHERE payment_auto_void_at IS NOT NULL AND status = 'pending';

-- Function to update updated_at
CREATE OR REPLACE FUNCTION update_customer_payment_methods_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_customer_payment_methods_updated_at
  BEFORE UPDATE ON customer_payment_methods
  FOR EACH ROW
  EXECUTE FUNCTION update_customer_payment_methods_updated_at();
```

---

### Phase 6: Testing (Days 10-11)

**Test Scenarios:**

1. **New Customer - Full Payment Flow**
   - Select digital payment → See fee breakdown
   - Enter card details → Check "Save card"
   - Payment authorized → Status: "Finding driver"
   - Driver accepts → Payment captured → Success ✅

2. **Returning Customer - Saved Card**
   - Select saved card: "•••• 1234"
   - One-click checkout → Auth → Capture ✅

3. **No Driver Available**
   - Payment authorized
   - Wait 24h (simulate with DB update)
   - Auto-void runs → Authorization cancelled
   - Customer sees: "No charge - drivers unavailable" ✅

4. **Customer Cancels Early**
   - Payment authorized
   - Customer cancels within 5 minutes
   - Manual void triggered → No charge ✅

5. **Webhook Failure Recovery**
   - Disable webhook temporarily
   - Complete payment
   - Status remains "authorized"
   - Enable webhook OR manual status check
   - Status updates correctly ✅

6. **Card Management**
   - Add 3 cards → All saved
   - Set default card
   - Delete card → Removed from DB
   - Check vault token NOT reusable ✅

**Maya Test Cards:**
```
Success: 4123450131001381
Declined: 4123450131001522
Insufficient Funds: 4123450131001001
CVV: 123
Expiry: Any future date
3DS OTP: 123456
```

---

### Phase 7: Production Deployment (Day 12)

**Pre-deployment Checklist:**
- [ ] All tests passing
- [ ] Sandbox integration verified
- [ ] Production Maya keys obtained
- [ ] Webhook URL registered with Maya production
- [ ] Auto-void cron job configured
- [ ] Monitoring/alerting setup
- [ ] Customer support trained
- [ ] Rollback plan documented

**Deployment Steps:**
1. Deploy database migration
2. Deploy edge functions to production
3. Update production secrets
4. Test with small real payment (₱10)
5. Monitor for 1 hour
6. Enable for 10% of users (beta)
7. Monitor for 24 hours
8. Full rollout

---

## Success Metrics

**Week 1 Targets:**
- Payment authorization success rate: **> 95%**
- Capture success rate: **> 99%**
- Webhook delivery rate: **> 99%**
- Auto-void false positives: **0**
- Customer complaints about fees: **< 5**
- Saved card adoption: **> 30%**

**Month 1 Targets:**
- 1000+ successful payments
- Average checkout time: **< 45 seconds**
- Returning customer using saved card: **> 50%**
- Refund rate: **< 2%** (down from ~5% without auth+capture)

---

## Cost Analysis

**Example Delivery: ₱200**

| Item | Amount |
|------|--------|
| Delivery Fee | ₱200.00 |
| Processing Fee (3.5% + ₱15) | ₱22.00 |
| **Customer Pays** | **₱222.00** |
| Platform Receives | ₱200.00 |
| Maya Takes | ₱22.00 |

**Monthly Volume: 10,000 deliveries**
- Average delivery: ₱200
- Total GMV: ₱2,000,000
- Total processing fees: ₱220,000 (paid by customers)
- Platform revenue: ₱2,000,000 (no fee impact)

---

## API Endpoints Summary

### Maya APIs We'll Use

1. **Payment RRNS (Auth+Capture)**
   - POST `/payments/v1/payment-rrns` - Authorize
   - POST `/payments/v1/payment-rrns/{id}/capture` - Capture
   - POST `/payments/v1/payment-rrns/{id}/void` - Void
   - GET `/payments/v1/payment-rrns/{id}` - Status

2. **Vault (Save Cards)**
   - POST `/payments/v1/payment-tokens` - Create token
   - GET `/payments/v1/payment-tokens/{id}` - Get token
   - DELETE `/payments/v1/payment-tokens/{id}` - Delete

3. **Webhooks**
   - Receive: `PAYMENT_AUTHORIZED`
   - Receive: `PAYMENT_CAPTURED`
   - Receive: `PAYMENT_VOIDED`
   - Receive: `PAYMENT_FAILED`

---

## Next Steps (RIGHT NOW)

1. ✅ Install Flutter dependencies
2. ✅ Create Supabase secrets
3. ✅ Run database migration
4. ✅ Start building Edge Function #1: `create-maya-checkout`

Let's GO! 🚀

---

**Status:** ✅ REQUIREMENTS CONFIRMED - IMPLEMENTATION STARTING

