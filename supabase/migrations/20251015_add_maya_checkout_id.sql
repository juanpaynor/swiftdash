-- Maya Checkout ID Addition
-- Date: October 15, 2025
-- Purpose: Add maya_checkout_id column to track Maya Checkout API response

-- Add maya_checkout_id column (this is the paymentId from Maya Checkout API)
ALTER TABLE deliveries 
  ADD COLUMN IF NOT EXISTS maya_checkout_id TEXT;

-- Add index for efficient lookups
CREATE INDEX IF NOT EXISTS idx_deliveries_maya_checkout 
  ON deliveries(maya_checkout_id) 
  WHERE maya_checkout_id IS NOT NULL;

-- Update comment
COMMENT ON COLUMN deliveries.maya_checkout_id IS 'Checkout ID from Maya Checkout API (used as paymentId for capture/void operations)';
COMMENT ON COLUMN deliveries.payment_authorization_id IS 'Alternative payment ID for compatibility';

-- Note: maya_checkout_id and payment_authorization_id may be the same value
-- maya_checkout_id is the primary identifier returned from POST /checkout/v1/checkouts
-- payment_authorization_id is kept for backwards compatibility
