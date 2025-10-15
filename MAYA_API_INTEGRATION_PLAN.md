# Maya Payment Gateway API Integration Plan

**Project:** SwiftDash Customer App  
**Date:** October 15, 2025  
**Approach:** Maya REST API (not Android SDK)  
**Status:** Planning Phase - NO CODING YET

---

## Executive Summary

This document outlines the complete plan to integrate Maya Payment Gateway using their REST API instead of the Android/iOS SDK approach. The Maya API provides a simpler, more flexible integration that works across all platforms (Android, iOS, Web) without platform-specific code.

**Key Decision:** Use Maya's Payment Link API (Checkout API) for web-based payment flows instead of native SDK.

---

## Table of Contents

1. [Current State Analysis](#1-current-state-analysis)
2. [Maya API Overview](#2-maya-api-overview)
3. [Architecture Design](#3-architecture-design)
4. [Implementation Phases](#4-implementation-phases)
5. [Technical Requirements](#5-technical-requirements)
6. [Security Considerations](#6-security-considerations)
7. [Testing Strategy](#7-testing-strategy)
8. [Deployment Plan](#8-deployment-plan)
9. [Rollback Plan](#9-rollback-plan)

---

## 1. Current State Analysis

### What We Have Now

**Frontend (Flutter):**
- ✅ Payment enums: `PaymentMethod`, `PaymentBy`, `PaymentStatus`
- ✅ Payment models: `PaymentConfig`, `PaymentResult`
- ✅ Payment service: `lib/services/payment_service.dart`
- ✅ UI integration: `OrderSummaryScreen` with payment selection
- ✅ Database fields: `maya_checkout_id`, `maya_payment_id`, `payment_status`

**Backend (Supabase):**
- ✅ Database schema: Delivery table with payment fields
- ✅ Edge function: `book_delivery` accepts payment data

**Current Implementation Issues:**
- ❌ Uses MethodChannel (platform-specific, requires native code)
- ❌ Mock Android implementation in MainActivity.kt
- ❌ No actual Maya API integration
- ❌ No webhook handling for payment confirmation
- ❌ No backend payment processing logic

### What Needs to Change

1. **Remove Platform Channels:** Delete MethodChannel approach from `payment_service.dart`
2. **Add HTTP Client:** Use `http` or `dio` package for REST API calls
3. **Backend Integration:** Create Supabase Edge Function for Maya API calls
4. **Webhook Handler:** Create endpoint to receive Maya payment status updates
5. **Payment Flow:** Implement web-based checkout (Payment Links)

---

## 2. Maya API Overview

### API Credentials

Maya provides TWO sets of keys:
- **Public Key:** Used in frontend (safe to expose)
- **Secret Key:** Used in backend ONLY (must be kept secure)

**Environments:**
- **Sandbox:** For testing - `https://pg-sandbox.paymaya.com`
- **Production:** For live payments - `https://pg.paymaya.com`

### Key Maya APIs We'll Use

#### 2.1 Checkout API (Payment Links)
**Purpose:** Create hosted payment page for customer

**Endpoint:** `POST /checkout/v1/checkouts`

**What it does:**
1. Creates a secure payment session
2. Returns a checkout URL
3. Customer completes payment on Maya's hosted page
4. Maya redirects back to your app

**Advantages:**
- ✅ PCI-DSS compliant (Maya handles card data)
- ✅ Works on all platforms (web view)
- ✅ Supports cards, Maya wallet, GCash, bank transfers
- ✅ Mobile-optimized checkout page

#### 2.2 Payment Webhooks
**Purpose:** Receive real-time payment status updates

**How it works:**
1. You register a webhook URL with Maya
2. Maya sends POST request when payment status changes
3. Your backend validates and processes the webhook

**Events:**
- `PAYMENT_SUCCESS` - Payment completed
- `PAYMENT_FAILED` - Payment failed
- `PAYMENT_EXPIRED` - Checkout session expired

#### 2.3 Retrieve Checkout API
**Purpose:** Check payment status manually

**Endpoint:** `GET /checkout/v1/checkouts/{checkoutId}`

**Use cases:**
- User returns to app without completing payment
- Webhook delivery failed
- Manual status verification

---

## 3. Architecture Design

### 3.1 Payment Flow Sequence

```
┌─────────────┐
│   Customer  │
│     App     │
└──────┬──────┘
       │
       │ 1. Create Delivery + Payment Config
       ▼
┌─────────────────────┐
│  Flutter App        │
│  (payment_service)  │
└──────┬──────────────┘
       │
       │ 2. HTTP POST /create-maya-checkout
       ▼
┌──────────────────────────┐
│  Supabase Edge Function  │
│  (create-maya-checkout)  │
└──────┬───────────────────┘
       │
       │ 3. POST /checkout/v1/checkouts
       ▼
┌─────────────────┐
│   Maya API      │
│   (Sandbox)     │
└──────┬──────────┘
       │
       │ 4. Returns checkoutUrl
       │
       ▼
┌──────────────────────┐
│  Flutter App         │
│  Opens WebView       │
│  (checkoutUrl)       │
└──────┬───────────────┘
       │
       │ 5. Customer pays on Maya page
       ▼
┌─────────────────┐
│   Maya Hosted   │
│   Checkout Page │
└──────┬──────────┘
       │
       │ 6. Webhook: PAYMENT_SUCCESS
       ▼
┌──────────────────────────┐
│  Supabase Edge Function  │
│  (maya-webhook)          │
└──────┬───────────────────┘
       │
       │ 7. Update delivery.payment_status = 'paid'
       ▼
┌─────────────────┐
│  PostgreSQL DB  │
└──────┬──────────┘
       │
       │ 8. Realtime notification
       ▼
┌──────────────────────┐
│  Flutter App         │
│  Shows success       │
└──────────────────────┘
```

### 3.2 Component Responsibilities

#### **Flutter App (Frontend)**
- Collect payment information
- Call backend to create Maya checkout
- Open Maya checkout URL in WebView/Browser
- Listen for payment completion
- Update UI based on payment status

#### **Supabase Edge Functions (Backend)**
- Store Maya secret key securely
- Create checkout sessions via Maya API
- Validate webhook signatures
- Update payment status in database
- Trigger realtime notifications

#### **Maya API (Third-party)**
- Host secure checkout page
- Process payments
- Send webhooks
- Provide payment status

---

## 4. Implementation Phases

### Phase 1: Environment Setup (Day 1)
**Goal:** Configure credentials and dependencies

**Tasks:**
1. ✅ Sign up for Maya Developer Account (https://developers.maya.ph/)
2. ✅ Get Sandbox API keys (public + secret)
3. ✅ Add environment variables to Supabase
4. ✅ Install Flutter packages: `http`, `webview_flutter`, `url_launcher`
5. ✅ Create `.env` file for local testing

**Deliverables:**
- Maya sandbox account created
- API keys documented securely
- Dependencies added to `pubspec.yaml`

---

### Phase 2: Backend API Integration (Days 2-3)
**Goal:** Create Supabase Edge Functions for Maya API

#### Task 2.1: Create Checkout Edge Function
**File:** `supabase/functions/create-maya-checkout/index.ts`

**Purpose:** Accept delivery/payment data, create Maya checkout session

**Input:**
```typescript
{
  deliveryId: string;
  amount: number;
  customerName: string;
  customerEmail?: string;
  customerPhone: string;
  description: string;
  metadata: {
    deliveryId: string;
    paymentBy: string;
    paymentMethod: string;
  };
}
```

**Output:**
```typescript
{
  success: boolean;
  checkoutId: string;
  checkoutUrl: string;
  expiresAt: string;
  error?: string;
}
```

**Steps:**
1. Validate request data
2. Call Maya Checkout API with secret key
3. Store checkout ID in delivery record
4. Return checkout URL to app

#### Task 2.2: Create Webhook Handler
**File:** `supabase/functions/maya-webhook/index.ts`

**Purpose:** Receive and process Maya payment webhooks

**Security:**
- Verify webhook signature using Maya secret key
- Validate webhook payload structure
- Prevent replay attacks (check timestamp)

**Actions:**
- Update `deliveries.payment_status`
- Update `deliveries.maya_payment_id`
- Update `deliveries.payment_processed_at`
- Trigger realtime notification to app

#### Task 2.3: Create Status Check Function
**File:** `supabase/functions/check-maya-payment/index.ts`

**Purpose:** Manually check payment status (fallback if webhook fails)

**Input:**
```typescript
{
  checkoutId: string;
  deliveryId: string;
}
```

**Output:**
```typescript
{
  status: 'paid' | 'pending' | 'failed' | 'expired';
  paymentId?: string;
  updatedAt: string;
}
```

**Deliverables:**
- 3 Edge Functions deployed
- Webhook URL registered with Maya
- Database triggers configured

---

### Phase 3: Flutter Service Refactoring (Days 4-5)
**Goal:** Rewrite `payment_service.dart` to use HTTP instead of MethodChannel

#### Task 3.1: Remove Platform Channel Code
**Changes to:** `lib/services/payment_service.dart`

**Remove:**
- `MethodChannel` import and instance
- All `_platform.invokeMethod()` calls
- Platform-specific initialization

**Add:**
- HTTP client (`http` package)
- Environment variables for API URLs
- Error handling for network requests

#### Task 3.2: Implement API-Based Payment Flow
**New methods:**

```dart
class PaymentService {
  static final http.Client _httpClient = http.Client();
  static const String _baseUrl = 'YOUR_SUPABASE_URL/functions/v1';
  
  /// Create Maya checkout and get payment URL
  static Future<PaymentResult> createCheckout(PaymentConfig config);
  
  /// Check payment status manually
  static Future<PaymentResult> checkPaymentStatus(String checkoutId);
  
  /// Handle redirect back from Maya
  static Future<PaymentResult> handlePaymentReturn(String checkoutId);
}
```

#### Task 3.3: WebView Integration
**Changes to:** `lib/screens/order_summary_screen.dart`

**Add:**
- `webview_flutter` package integration
- Open Maya checkout URL in WebView
- Listen for return URLs
- Handle payment success/failure redirects

**Deliverables:**
- Refactored `payment_service.dart` (no platform channels)
- WebView payment flow implemented
- Error handling for network failures

---

### Phase 4: Database Schema Updates (Day 6)
**Goal:** Ensure database supports new payment flow

#### Task 4.1: Review Existing Schema
**Current fields in `deliveries` table:**
- ✅ `maya_checkout_id` - Good
- ✅ `maya_payment_id` - Good
- ✅ `payment_status` - Good
- ✅ `payment_processed_at` - Good
- ✅ `payment_metadata` - Good

#### Task 4.2: Add Webhook Tracking (Optional)
**New table:** `payment_webhooks`

**Purpose:** Log all webhook events for debugging

**Schema:**
```sql
CREATE TABLE payment_webhooks (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  delivery_id UUID REFERENCES deliveries(id),
  checkout_id TEXT NOT NULL,
  event_type TEXT NOT NULL,
  payload JSONB NOT NULL,
  signature TEXT,
  verified BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);
```

**Deliverables:**
- Schema review completed
- Optional webhook logging table created
- RLS policies configured

---

### Phase 5: Testing Implementation (Days 7-9)
**Goal:** Thorough testing with Maya Sandbox

#### Task 5.1: Unit Tests
**Files to test:**
- `payment_service.dart` - Mock HTTP responses
- `payment_config.dart` - Data validation
- `payment_result.dart` - JSON parsing

#### Task 5.2: Integration Tests
**Scenarios:**
1. **Successful Card Payment**
   - Test card: `4123450131001381`
   - Expected: Payment completes, webhook received, status = 'paid'

2. **Successful Maya Wallet Payment**
   - Test wallet: Sandbox account
   - Expected: Payment completes, status = 'paid'

3. **Failed Payment**
   - Test card: `4123450131001522` (declined)
   - Expected: Error shown, status = 'failed'

4. **Expired Checkout**
   - Wait for checkout expiry (default 1 hour)
   - Expected: Status = 'expired', graceful handling

5. **Webhook Failure Recovery**
   - Disable webhook temporarily
   - Complete payment
   - Re-enable and call status check
   - Expected: Status updated via manual check

6. **Network Failure Handling**
   - Simulate offline mode
   - Expected: Clear error message, retry option

#### Task 5.3: End-to-End Testing
**Full delivery flow:**
1. Create delivery with Maya payment
2. Complete checkout on Maya page
3. Verify webhook updates database
4. Check app shows success
5. Verify delivery is assigned to driver

**Deliverables:**
- Test cases documented
- All tests passing in sandbox
- Bug fixes applied

---

### Phase 6: UI/UX Enhancements (Day 10)
**Goal:** Smooth payment experience

#### Task 6.1: Loading States
- Show spinner while creating checkout
- Loading overlay during payment processing
- Skeleton screens for payment status

#### Task 6.2: Error Messages
**User-friendly messages:**
- "Unable to connect to payment service" (network error)
- "Payment was declined by your bank" (card declined)
- "Payment session expired, please try again" (timeout)

#### Task 6.3: Success/Failure Screens
- Animated success checkmark
- Payment receipt details
- Option to download receipt (future)

**Deliverables:**
- Polished UI for all payment states
- Clear error messaging
- Smooth transitions

---

### Phase 7: Production Preparation (Days 11-12)
**Goal:** Ready for live payments

#### Task 7.1: Switch to Production Credentials
- Get Maya production API keys
- Update environment variables
- Test with small real payment

#### Task 7.2: Monitoring Setup
- Log all payment attempts
- Alert on payment failures
- Dashboard for payment metrics

#### Task 7.3: Documentation
- Developer guide for payment flow
- Troubleshooting guide
- Customer support FAQ

**Deliverables:**
- Production keys configured
- Monitoring active
- Documentation complete

---

### Phase 8: Deployment (Day 13)
**Goal:** Launch to production

#### Task 8.1: Staged Rollout
1. Internal team testing (5 users)
2. Beta users (50 users)
3. Full rollout (all users)

#### Task 8.2: Feature Flag
- Enable/disable Maya payments
- Fallback to cash-only if issues arise

**Deliverables:**
- Maya payments live in production
- Monitoring all green
- Support team briefed

---

## 5. Technical Requirements

### 5.1 Flutter Dependencies

**Add to `pubspec.yaml`:**
```yaml
dependencies:
  http: ^1.1.0              # HTTP client for API calls
  webview_flutter: ^4.4.2   # For Maya checkout page
  url_launcher: ^6.2.1      # Handle deep links
  flutter_dotenv: ^5.1.0    # Environment variables
  
dev_dependencies:
  mockito: ^5.4.3           # Mock HTTP for testing
  http_mock_adapter: ^0.6.1 # Mock HTTP responses
```

### 5.2 Supabase Edge Functions

**Required packages:**
```json
{
  "dependencies": {
    "@supabase/supabase-js": "^2.38.0",
    "crypto": "^1.0.3"  // For webhook signature validation
  }
}
```

### 5.3 Environment Variables

**Supabase Secrets:**
```bash
# Maya API Credentials
MAYA_PUBLIC_KEY=pk-...
MAYA_SECRET_KEY=sk-...
MAYA_WEBHOOK_SECRET=whsec_...

# Environment
MAYA_ENVIRONMENT=sandbox  # or 'production'
MAYA_API_URL=https://pg-sandbox.paymaya.com

# Webhook URL
MAYA_WEBHOOK_URL=https://your-project.supabase.co/functions/v1/maya-webhook
```

**Flutter `.env` file:**
```bash
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_ANON_KEY=eyJ...
MAYA_PUBLIC_KEY=pk-...
MAYA_ENVIRONMENT=sandbox
```

---

## 6. Security Considerations

### 6.1 API Key Management

**DO:**
- ✅ Store secret key ONLY in Supabase Edge Functions
- ✅ Use environment variables (never hardcode)
- ✅ Rotate keys periodically
- ✅ Use different keys for sandbox/production

**DON'T:**
- ❌ Never expose secret key in Flutter code
- ❌ Never commit keys to Git
- ❌ Never log secret keys

### 6.2 Webhook Security

**Required validations:**
1. **Signature Verification:** Validate Maya's signature header
2. **Timestamp Check:** Reject old webhooks (prevent replay)
3. **Idempotency:** Handle duplicate webhooks gracefully
4. **HTTPS Only:** Webhook endpoint must use HTTPS

**Example signature validation:**
```typescript
import crypto from 'crypto';

function verifyWebhookSignature(payload: string, signature: string, secret: string): boolean {
  const computedSignature = crypto
    .createHmac('sha256', secret)
    .update(payload)
    .digest('hex');
  
  return crypto.timingSafeEqual(
    Buffer.from(signature),
    Buffer.from(computedSignature)
  );
}
```

### 6.3 Data Privacy

**PCI-DSS Compliance:**
- ✅ Never store card numbers
- ✅ Never store CVV
- ✅ Let Maya handle all card data
- ✅ Use tokenization for recurring payments (future)

**Customer Data:**
- Store only: name, email, phone (encrypted at rest)
- Log payment attempts (no sensitive data)
- Comply with data retention policies

---

## 7. Testing Strategy

### 7.1 Maya Sandbox Test Credentials

**Test Cards:**
```
Success: 4123450131001381
Declined: 4123450131001522
Insufficient Funds: 4123450131001001
```

**Test CVV:** `123` (any)
**Test Expiry:** Any future date
**Test 3DS OTP:** `123456`

**Test Maya Wallet:**
- Email: `test@paymaya.com`
- Password: Provided in Maya dashboard

### 7.2 Test Cases

#### Critical Path Tests
1. ✅ Create checkout → Success
2. ✅ Complete payment → Webhook received → Status updated
3. ✅ Cancel payment → Status remains pending
4. ✅ Expired checkout → Error handled gracefully

#### Edge Cases
1. ✅ Duplicate checkout creation (idempotency)
2. ✅ Webhook received before status check
3. ✅ Multiple webhooks for same payment
4. ✅ App closed during payment (resume handling)

#### Error Scenarios
1. ✅ Network timeout during checkout creation
2. ✅ Invalid API credentials
3. ✅ Maya API downtime
4. ✅ Webhook signature mismatch

### 7.3 Performance Tests

**Targets:**
- Checkout creation: < 2 seconds
- Webhook processing: < 500ms
- Status check: < 1 second

**Load testing:**
- 100 concurrent checkout creations
- 1000 webhooks per minute

---

## 8. Deployment Plan

### 8.1 Pre-Deployment Checklist

- [ ] All tests passing in sandbox
- [ ] Production API keys obtained
- [ ] Webhook URL registered with Maya
- [ ] Monitoring/alerting configured
- [ ] Rollback plan documented
- [ ] Team trained on new flow
- [ ] Customer support informed

### 8.2 Deployment Steps

**Step 1: Deploy Edge Functions**
```bash
# Test in staging first
supabase functions deploy create-maya-checkout --project-ref staging
supabase functions deploy maya-webhook --project-ref staging
supabase functions deploy check-maya-payment --project-ref staging

# Verify in staging
# Run integration tests

# Deploy to production
supabase functions deploy create-maya-checkout --project-ref production
supabase functions deploy maya-webhook --project-ref production
supabase functions deploy check-maya-payment --project-ref production
```

**Step 2: Update Environment Variables**
```bash
# Set production secrets
supabase secrets set MAYA_SECRET_KEY=sk_prod_... --project-ref production
supabase secrets set MAYA_PUBLIC_KEY=pk_prod_... --project-ref production
supabase secrets set MAYA_ENVIRONMENT=production --project-ref production
```

**Step 3: Deploy Flutter App**
```bash
# Build and test
flutter build apk --release
flutter build ios --release

# Internal testing (1 day)
# Beta testing (2 days)
# Full rollout
```

**Step 4: Monitor First 24 Hours**
- Watch payment success rate
- Check webhook delivery rate
- Monitor error logs
- Verify realtime updates

### 8.3 Success Metrics

**Day 1 Targets:**
- Payment success rate: > 95%
- Webhook delivery: > 99%
- Average checkout time: < 3 seconds
- Zero critical errors

**Week 1 Targets:**
- 100+ successful payments
- Customer satisfaction: > 4.5/5
- Support tickets: < 5 payment-related
- Zero data breaches

---

## 9. Rollback Plan

### 9.1 If Maya Integration Fails

**Immediate Actions:**
1. Disable Maya payments via feature flag
2. Fall back to cash-only payments
3. Notify customers via in-app banner

**Rollback Steps:**
```dart
// Feature flag check
if (FeatureFlags.mayaPaymentsEnabled) {
  // Show credit card, Maya wallet options
} else {
  // Show cash only
}
```

### 9.2 If Webhooks Fail

**Fallback mechanism:**
- Use polling (check payment status every 10 seconds)
- Maximum 6 attempts (1 minute total)
- Then prompt user to refresh manually

**Code:**
```dart
// Fallback to polling if webhook doesn't arrive within 30 seconds
Future<void> pollPaymentStatus(String checkoutId) async {
  for (int i = 0; i < 6; i++) {
    await Future.delayed(Duration(seconds: 10));
    final result = await PaymentService.checkPaymentStatus(checkoutId);
    if (result.status != PaymentStatus.pending) {
      return; // Status updated
    }
  }
  // Prompt user
}
```

### 9.3 Database Rollback

**If payment data corrupted:**
```sql
-- Backup before deployment
pg_dump deliveries > backup_pre_maya_$(date +%Y%m%d).sql

-- Restore if needed
psql < backup_pre_maya_YYYYMMDD.sql
```

---

## 10. Cost Estimation

### 10.1 Maya Transaction Fees

**Pricing (as of 2025):**
- Credit/Debit Cards: 3.5% + ₱15 per transaction
- Maya Wallet: 2.5% per transaction
- Bank Transfer: 1.5% + ₱15 per transaction

**Example:**
- Delivery fee: ₱200
- Card payment fee: ₱200 × 3.5% + ₱15 = ₱22
- **Total charged to customer: ₱222**

**Decision:** Should customer or company absorb fees?
- Option A: Pass to customer (higher price, transparent)
- Option B: Company absorbs (lower price, thinner margins)

### 10.2 Infrastructure Costs

**Supabase Edge Functions:**
- Free tier: 500K requests/month
- After: $0.40 per 1M requests

**Estimated monthly costs:**
- 10,000 deliveries = 30,000 function calls
- Cost: $0.012 (~₱0.67)
- **Negligible cost**

---

## 11. Future Enhancements

### Phase 2 Features (Post-Launch)

1. **Saved Payment Methods**
   - Tokenize cards for faster checkout
   - "Pay with saved card" option

2. **Refunds API**
   - Automatic refunds for cancelled deliveries
   - Partial refunds for issues

3. **Split Payments**
   - Sender pays ₱100, recipient pays ₱100
   - Multiple payment sources

4. **Payment Analytics**
   - Dashboard for payment success rates
   - Decline reason analysis
   - Revenue metrics

5. **Alternative Payment Methods**
   - GCash integration
   - GrabPay
   - Bank transfer

---

## 12. Key Takeaways

### Why Maya API > Android SDK

| Aspect | Android SDK | REST API |
|--------|-------------|----------|
| **Platform Support** | Android only | All platforms |
| **Implementation** | Complex native code | Simple HTTP calls |
| **Maintenance** | Update SDK regularly | Stable API contract |
| **Testing** | Requires emulator/device | Easy unit tests |
| **Debugging** | Native logs | HTTP logs |
| **Web Support** | ❌ Not possible | ✅ Works everywhere |

### Critical Success Factors

1. ✅ **Webhook reliability:** Must receive 99%+ of webhooks
2. ✅ **Error handling:** Clear messages for all failure scenarios
3. ✅ **Security:** Never expose secret key in frontend
4. ✅ **Testing:** Thorough sandbox testing before production
5. ✅ **Monitoring:** Real-time alerts on payment failures

### Timeline Summary

| Phase | Duration | Status |
|-------|----------|--------|
| Phase 1: Setup | 1 day | Not started |
| Phase 2: Backend | 2 days | Not started |
| Phase 3: Frontend | 2 days | Not started |
| Phase 4: Database | 1 day | Not started |
| Phase 5: Testing | 3 days | Not started |
| Phase 6: UI Polish | 1 day | Not started |
| Phase 7: Production Prep | 2 days | Not started |
| Phase 8: Deployment | 1 day | Not started |
| **Total** | **13 days** | **Planning** |

---

## 13. Next Steps

### Immediate Actions (Today)

1. **Review this plan** with the team
2. **Sign up for Maya Developer Account** (https://developers.maya.ph/)
3. **Get sandbox credentials** (public + secret keys)
4. **Decide on payment fee strategy** (pass to customer or absorb)
5. **Approve to start Phase 1** (no coding until approved)

### Questions to Answer Before Coding

1. ❓ Should we pass payment fees to customers or absorb them?
2. ❓ What should checkout session expiry be? (Default: 1 hour)
3. ❓ Do we want to save payment methods for future use?
4. ❓ Should we support installment payments? (Maya feature)
5. ❓ What's the rollback trigger? (X% failure rate = disable?)

---

## 14. Resources & References

### Maya Documentation
- **Developer Portal:** https://developers.maya.ph/
- **Checkout API Docs:** https://developers.maya.ph/docs/checkout-api
- **Webhook Guide:** https://developers.maya.ph/docs/webhooks
- **Test Cards:** https://developers.maya.ph/docs/testing

### Code Examples
- **Maya PHP SDK:** https://github.com/PayMaya/PayMaya-PHP-SDK
- **Maya Node.js:** https://github.com/PayMaya/PayMaya-Node-SDK

### Support
- **Developer Support:** developers@maya.ph
- **Slack Community:** https://paymaya-dev.slack.com
- **Response Time:** 1-2 business days

---

## Document Change Log

| Date | Version | Changes | Author |
|------|---------|---------|--------|
| Oct 15, 2025 | 1.0 | Initial plan created | AI Assistant |

---

**Status:** ✅ PLAN COMPLETE - AWAITING APPROVAL TO START IMPLEMENTATION

**Next Review:** After Phase 1 completion

---

