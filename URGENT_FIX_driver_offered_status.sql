-- URGENT FIX: Enhanced Driver Flow Status Update - October 10, 2025
-- This fixes the missing 'driver_offered' status that was causing pair_driver function to fail

-- 1. Drop the incorrect constraint first
ALTER TABLE deliveries 
DROP CONSTRAINT deliveries_status_check;

-- 2. Add the CORRECTED constraint with ALL status values including 'driver_offered'
ALTER TABLE deliveries 
ADD CONSTRAINT deliveries_status_check 
CHECK (status IN (
  -- Core workflow statuses
  'pending',             -- Order created, looking for driver
  'driver_offered',      -- ✅ CRITICAL: Driver found but not yet accepted (used by pair_driver)
  'driver_assigned',     -- Driver accepted order
  
  -- Enhanced driver flow statuses
  'going_to_pickup',     -- NEW: Driver navigating to pickup location
  'pickup_arrived',      -- Driver at pickup location
  'package_collected',   -- Package picked up
  'going_to_destination', -- NEW: Driver navigating to delivery location
  'at_destination',      -- NEW: Driver arrived at delivery location
  'in_transit',          -- Heading to destination (legacy)
  'delivered',           -- Completed with POD
  
  -- Error states
  'cancelled',           -- Cancelled by customer/driver
  'failed'               -- Delivery failed
));

-- 3. Verify the constraint includes 'driver_offered'
SELECT 
    tc.constraint_name,
    cc.check_clause,
    tc.table_name
FROM information_schema.table_constraints tc
JOIN information_schema.check_constraints cc 
    ON tc.constraint_name = cc.constraint_name
WHERE tc.table_name = 'deliveries' 
    AND tc.constraint_type = 'CHECK'
    AND tc.constraint_name LIKE '%status%';

-- 4. Test that 'driver_offered' status now works
-- This query should succeed without constraint violation:
/*
UPDATE deliveries 
SET status = 'driver_offered', 
    updated_at = NOW()
WHERE status = 'pending' 
LIMIT 1;
*/

-- Success message
SELECT 'FIXED: driver_offered status now supported - pair_driver function should work!' as result;