-- Enhanced Driver Flow Status Update - October 10, 2025
-- Adding new status values for enhanced driver flow

-- 1. First check current constraint
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

-- 2. Drop existing constraint
ALTER TABLE deliveries 
DROP CONSTRAINT deliveries_status_check;

-- 3. Add enhanced constraint with new status values
ALTER TABLE deliveries 
ADD CONSTRAINT deliveries_status_check 
CHECK (status IN (
  -- Existing status values (keep all)
  'pending',           -- Order created, looking for driver
  'driver_offered',    -- Driver found but not yet accepted (CRITICAL - used by pair_driver)
  'driver_assigned',   -- Driver accepted order (your "Accept Order")
  'pickup_arrived',    -- Driver at pickup location (your "Arrive at Pickup") 
  'package_collected', -- Package picked up (your "Package Collected")
  'in_transit',        -- Heading to destination
  'delivered',         -- Completed with POD
  'cancelled',         -- Cancelled by customer/driver
  'failed',            -- Delivery failed
  
  -- NEW status values for enhanced driver flow
  'going_to_pickup',     -- Driver navigating to pickup location
  'going_to_destination', -- Driver navigating to delivery location
  'at_destination'       -- Driver arrived at delivery location
));

-- 4. Verify the constraint was added correctly
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

-- 5. Optional: Add index for new status values (performance optimization)
CREATE INDEX IF NOT EXISTS idx_deliveries_enhanced_status 
ON deliveries(status, driver_id, updated_at) 
WHERE status IN ('going_to_pickup', 'going_to_destination', 'at_destination');

-- 6. Test the new constraint with sample data
-- This should work without errors:
/*
INSERT INTO deliveries (
  customer_id, vehicle_type_id, pickup_address, pickup_latitude, pickup_longitude,
  pickup_contact_name, pickup_contact_phone, delivery_address, delivery_latitude,
  delivery_longitude, delivery_contact_name, delivery_contact_phone,
  package_description, total_price, status, total_amount
) VALUES (
  'test-customer-id', 'test-vehicle-id', 'Test Pickup', 14.5995, 120.9842,
  'Test Pickup Contact', '09123456789', 'Test Delivery', 14.6042, 121.0234,
  'Test Delivery Contact', '09987654321', 'Test Package', 100.00, 
  'going_to_pickup', 100.00  -- NEW status value should work
);
*/

-- Success message
SELECT 'Enhanced driver flow status values added successfully!' as result;