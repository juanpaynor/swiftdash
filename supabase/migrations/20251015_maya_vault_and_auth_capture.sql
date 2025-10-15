-- Maya Payment Gateway Integration: Vault & Auth+Capture
-- Date: October 15, 2025
-- Purpose: Add support for saved payment methods and payment authorization/capture flow

-- ============================================
-- 1. Customer Payment Methods Table (Vault)
-- ============================================

-- Table to store Maya vault tokens for saved payment methods
CREATE TABLE IF NOT EXISTS customer_payment_methods (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  customer_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  
  -- Maya Vault Token (never store actual card numbers!)
  card_token TEXT NOT NULL UNIQUE,
  
  -- Card Metadata (for display purposes only)
  card_type TEXT, -- 'VISA', 'MASTERCARD', 'JCB', 'AMEX'
  last_four_digits TEXT, -- '1234' for displaying '•••• 1234'
  card_brand TEXT, -- 'visa', 'mastercard', etc.
  expiry_month INTEGER, -- 1-12
  expiry_year INTEGER, -- YYYY format
  
  -- Management
  is_default BOOLEAN DEFAULT FALSE,
  is_active BOOLEAN DEFAULT TRUE, -- For soft delete
  
  -- Timestamps
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  last_used_at TIMESTAMPTZ,
  
  -- Constraints
  CONSTRAINT valid_expiry_month CHECK (expiry_month >= 1 AND expiry_month <= 12),
  CONSTRAINT valid_expiry_year CHECK (expiry_year >= 2025),
  CONSTRAINT valid_last_four CHECK (last_four_digits ~ '^\d{4}$'),
  CONSTRAINT unique_customer_card UNIQUE(customer_id, card_token)
);

-- Indexes for performance
CREATE INDEX idx_customer_payment_methods_customer 
  ON customer_payment_methods(customer_id) 
  WHERE is_active = TRUE;

CREATE INDEX idx_customer_payment_methods_default 
  ON customer_payment_methods(customer_id, is_default) 
  WHERE is_default = TRUE AND is_active = TRUE;

-- RLS Policies
ALTER TABLE customer_payment_methods ENABLE ROW LEVEL SECURITY;

-- Users can only view their own payment methods
CREATE POLICY "Users can view own payment methods"
  ON customer_payment_methods FOR SELECT
  USING (auth.uid() = customer_id);

-- Users can only insert their own payment methods
CREATE POLICY "Users can insert own payment methods"
  ON customer_payment_methods FOR INSERT
  WITH CHECK (auth.uid() = customer_id);

-- Users can only update their own payment methods
CREATE POLICY "Users can update own payment methods"
  ON customer_payment_methods FOR UPDATE
  USING (auth.uid() = customer_id);

-- Users can only delete their own payment methods (soft delete preferred)
CREATE POLICY "Users can delete own payment methods"
  ON customer_payment_methods FOR DELETE
  USING (auth.uid() = customer_id);

-- Trigger to update updated_at timestamp
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

-- Function to ensure only one default card per customer
CREATE OR REPLACE FUNCTION ensure_single_default_payment_method()
RETURNS TRIGGER AS $$
BEGIN
  -- If setting this card as default, unset all other defaults for this customer
  IF NEW.is_default = TRUE THEN
    UPDATE customer_payment_methods
    SET is_default = FALSE
    WHERE customer_id = NEW.customer_id
      AND id != NEW.id
      AND is_default = TRUE;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_ensure_single_default
  BEFORE INSERT OR UPDATE ON customer_payment_methods
  FOR EACH ROW
  WHEN (NEW.is_default = TRUE)
  EXECUTE FUNCTION ensure_single_default_payment_method();

-- ============================================
-- 2. Add Auth+Capture Fields to Deliveries
-- ============================================

-- Add payment authorization and capture tracking fields
ALTER TABLE deliveries 
  ADD COLUMN IF NOT EXISTS payment_authorization_id TEXT,
  ADD COLUMN IF NOT EXISTS payment_authorized_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS payment_captured_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS payment_void_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS payment_auto_void_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS payment_processing_fee DECIMAL(10, 2) DEFAULT 0,
  ADD COLUMN IF NOT EXISTS payment_total_amount DECIMAL(10, 2); -- Delivery fee + processing fee

-- Index for auto-void background job
CREATE INDEX IF NOT EXISTS idx_deliveries_auto_void 
  ON deliveries(payment_auto_void_at, status) 
  WHERE payment_auto_void_at IS NOT NULL 
    AND status IN ('pending', 'searching_driver')
    AND payment_void_at IS NULL;

-- Index for payment authorization lookup
CREATE INDEX IF NOT EXISTS idx_deliveries_payment_authorization 
  ON deliveries(payment_authorization_id) 
  WHERE payment_authorization_id IS NOT NULL;

-- ============================================
-- 3. Payment Webhook Log Table
-- ============================================

-- Table to log all Maya webhook events for debugging and auditing
CREATE TABLE IF NOT EXISTS payment_webhook_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  
  -- Webhook Data
  delivery_id UUID REFERENCES deliveries(id) ON DELETE CASCADE,
  checkout_id TEXT,
  payment_id TEXT,
  event_type TEXT NOT NULL, -- 'AUTHORIZED', 'CAPTURED', 'VOIDED', 'FAILED', 'EXPIRED'
  
  -- Raw Payload
  payload JSONB NOT NULL,
  headers JSONB, -- Store headers for debugging
  
  -- Security
  signature TEXT,
  signature_verified BOOLEAN DEFAULT FALSE,
  
  -- Processing
  processed BOOLEAN DEFAULT FALSE,
  processed_at TIMESTAMPTZ,
  error_message TEXT,
  
  -- Timestamps
  received_at TIMESTAMPTZ DEFAULT NOW(),
  
  -- Metadata
  ip_address TEXT,
  user_agent TEXT
);

-- Indexes for webhook logs
CREATE INDEX idx_webhook_logs_delivery ON payment_webhook_logs(delivery_id);
CREATE INDEX idx_webhook_logs_checkout ON payment_webhook_logs(checkout_id);
CREATE INDEX idx_webhook_logs_event ON payment_webhook_logs(event_type, received_at DESC);
CREATE INDEX idx_webhook_logs_unprocessed ON payment_webhook_logs(processed, received_at) WHERE processed = FALSE;

-- RLS for webhook logs (admin only)
ALTER TABLE payment_webhook_logs ENABLE ROW LEVEL SECURITY;

-- Only service role can access webhook logs
CREATE POLICY "Service role can access webhook logs"
  ON payment_webhook_logs
  USING (auth.jwt()->>'role' = 'service_role');

-- ============================================
-- 4. Helper Functions
-- ============================================

-- Function to get active saved cards for a customer
CREATE OR REPLACE FUNCTION get_customer_saved_cards(p_customer_id UUID)
RETURNS TABLE (
  id UUID,
  card_type TEXT,
  last_four_digits TEXT,
  expiry_month INTEGER,
  expiry_year INTEGER,
  is_default BOOLEAN,
  is_expired BOOLEAN,
  created_at TIMESTAMPTZ,
  last_used_at TIMESTAMPTZ
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    cpm.id,
    cpm.card_type,
    cpm.last_four_digits,
    cpm.expiry_month,
    cpm.expiry_year,
    cpm.is_default,
    -- Check if card is expired
    (
      (cpm.expiry_year < EXTRACT(YEAR FROM NOW())) OR
      (cpm.expiry_year = EXTRACT(YEAR FROM NOW()) AND cpm.expiry_month < EXTRACT(MONTH FROM NOW()))
    ) AS is_expired,
    cpm.created_at,
    cpm.last_used_at
  FROM customer_payment_methods cpm
  WHERE cpm.customer_id = p_customer_id
    AND cpm.is_active = TRUE
  ORDER BY 
    cpm.is_default DESC, 
    cpm.last_used_at DESC NULLS LAST,
    cpm.created_at DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to mark delivery payment as authorized
CREATE OR REPLACE FUNCTION authorize_delivery_payment(
  p_delivery_id UUID,
  p_authorization_id TEXT,
  p_total_amount DECIMAL,
  p_processing_fee DECIMAL,
  p_auto_void_hours INTEGER DEFAULT 24
)
RETURNS BOOLEAN AS $$
BEGIN
  UPDATE deliveries
  SET 
    payment_authorization_id = p_authorization_id,
    payment_authorized_at = NOW(),
    payment_auto_void_at = NOW() + (p_auto_void_hours || ' hours')::INTERVAL,
    payment_total_amount = p_total_amount,
    payment_processing_fee = p_processing_fee,
    payment_status = 'authorized',
    updated_at = NOW()
  WHERE id = p_delivery_id;
  
  RETURN FOUND;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to mark delivery payment as captured
CREATE OR REPLACE FUNCTION capture_delivery_payment(
  p_delivery_id UUID,
  p_payment_id TEXT
)
RETURNS BOOLEAN AS $$
BEGIN
  UPDATE deliveries
  SET 
    maya_payment_id = p_payment_id,
    payment_captured_at = NOW(),
    payment_status = 'paid',
    payment_auto_void_at = NULL, -- Clear auto-void since payment is captured
    updated_at = NOW()
  WHERE id = p_delivery_id;
  
  RETURN FOUND;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to void delivery payment
CREATE OR REPLACE FUNCTION void_delivery_payment(
  p_delivery_id UUID,
  p_reason TEXT DEFAULT NULL
)
RETURNS BOOLEAN AS $$
BEGIN
  UPDATE deliveries
  SET 
    payment_void_at = NOW(),
    payment_status = 'voided',
    payment_error_message = COALESCE(p_reason, 'Payment authorization voided'),
    payment_auto_void_at = NULL,
    updated_at = NOW()
  WHERE id = p_delivery_id;
  
  RETURN FOUND;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to find deliveries that need auto-void
CREATE OR REPLACE FUNCTION get_deliveries_for_auto_void()
RETURNS TABLE (
  delivery_id UUID,
  authorization_id TEXT,
  customer_id UUID,
  auto_void_at TIMESTAMPTZ,
  hours_since_authorized NUMERIC
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    d.id AS delivery_id,
    d.payment_authorization_id AS authorization_id,
    d.customer_id,
    d.payment_auto_void_at AS auto_void_at,
    EXTRACT(EPOCH FROM (NOW() - d.payment_authorized_at)) / 3600 AS hours_since_authorized
  FROM deliveries d
  WHERE d.payment_auto_void_at IS NOT NULL
    AND d.payment_auto_void_at <= NOW()
    AND d.status IN ('pending', 'searching_driver')
    AND d.payment_void_at IS NULL
    AND d.payment_captured_at IS NULL
    AND d.payment_authorization_id IS NOT NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================
-- 5. Update Existing Payment Status Values
-- ============================================

-- Add new payment status values if needed
-- Existing: 'pending', 'paid', 'failed', 'cash_pending'
-- New: 'authorized', 'voided'

COMMENT ON COLUMN deliveries.payment_status IS 
  'Payment status: pending, authorized, paid, voided, failed, cash_pending';

-- ============================================
-- 6. Grant Permissions
-- ============================================

-- Grant SELECT on new table to authenticated users (through RLS)
GRANT SELECT, INSERT, UPDATE, DELETE ON customer_payment_methods TO authenticated;
GRANT USAGE ON SEQUENCE customer_payment_methods_id_seq TO authenticated;

-- Grant access to webhook logs (service role only)
GRANT ALL ON payment_webhook_logs TO service_role;

-- Grant execution of helper functions
GRANT EXECUTE ON FUNCTION get_customer_saved_cards TO authenticated;
GRANT EXECUTE ON FUNCTION authorize_delivery_payment TO service_role;
GRANT EXECUTE ON FUNCTION capture_delivery_payment TO service_role;
GRANT EXECUTE ON FUNCTION void_delivery_payment TO service_role;
GRANT EXECUTE ON FUNCTION get_deliveries_for_auto_void TO service_role;

-- ============================================
-- 7. Comments for Documentation
-- ============================================

COMMENT ON TABLE customer_payment_methods IS 
  'Stores Maya vault tokens for saved payment methods. Never stores actual card numbers.';

COMMENT ON TABLE payment_webhook_logs IS 
  'Logs all Maya webhook events for debugging and auditing purposes.';

COMMENT ON COLUMN deliveries.payment_authorization_id IS 
  'Maya authorization ID for payment hold (before capture)';

COMMENT ON COLUMN deliveries.payment_auto_void_at IS 
  'Timestamp when payment authorization should be automatically voided (typically 24h after authorization)';

COMMENT ON COLUMN deliveries.payment_processing_fee IS 
  'Payment processing fee charged to customer (e.g., 3.5% + ₱15 for cards)';

COMMENT ON COLUMN deliveries.payment_total_amount IS 
  'Total amount charged including delivery fee + processing fee';

-- ============================================
-- Migration Complete
-- ============================================

-- Log migration completion
DO $$
BEGIN
  RAISE NOTICE 'Maya Vault & Auth+Capture migration completed successfully';
  RAISE NOTICE 'Tables created: customer_payment_methods, payment_webhook_logs';
  RAISE NOTICE 'Functions created: get_customer_saved_cards, authorize_delivery_payment, capture_delivery_payment, void_delivery_payment, get_deliveries_for_auto_void';
  RAISE NOTICE 'Indexes created for performance optimization';
  RAISE NOTICE 'RLS policies enabled for security';
END $$;
