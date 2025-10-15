-- =====================================================
-- SAVED ADDRESSES TABLE
-- Stores user's frequently used addresses (Home, Office, etc.)
-- =====================================================

CREATE TABLE IF NOT EXISTS saved_addresses (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    
    -- Address identification
    label VARCHAR(100) NOT NULL, -- "Home", "Office", "Warehouse A", etc.
    emoji VARCHAR(10) NOT NULL DEFAULT '📍', -- 🏠, 🏢, 📦, etc.
    
    -- Full address details
    full_address TEXT NOT NULL,
    latitude DOUBLE PRECISION NOT NULL,
    longitude DOUBLE PRECISION NOT NULL,
    
    -- Detailed address components (optional)
    house_number VARCHAR(50),
    street VARCHAR(255),
    barangay VARCHAR(255),
    city VARCHAR(255),
    province VARCHAR(255),
    
    -- Metadata
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ,
    
    -- Constraints
    CONSTRAINT valid_coordinates CHECK (
        latitude BETWEEN -90 AND 90 AND 
        longitude BETWEEN -180 AND 180
    ),
    
    -- Prevent duplicate labels per user
    UNIQUE(user_id, label)
);

-- =====================================================
-- INDEXES FOR PERFORMANCE
-- =====================================================

-- Fast lookups by user_id
CREATE INDEX idx_saved_addresses_user_id ON saved_addresses(user_id);

-- Fast ordering by creation time
CREATE INDEX idx_saved_addresses_created_at ON saved_addresses(created_at DESC);

-- Search by label
CREATE INDEX idx_saved_addresses_label ON saved_addresses(label);

-- Spatial queries (if needed later)
CREATE INDEX idx_saved_addresses_location ON saved_addresses USING GIST (
    point(longitude, latitude)
);

-- =====================================================
-- ROW LEVEL SECURITY (RLS)
-- =====================================================

-- Enable RLS
ALTER TABLE saved_addresses ENABLE ROW LEVEL SECURITY;

-- Users can only see their own saved addresses
CREATE POLICY "Users can view their own saved addresses"
    ON saved_addresses
    FOR SELECT
    USING (auth.uid() = user_id);

-- Users can insert their own saved addresses
CREATE POLICY "Users can insert their own saved addresses"
    ON saved_addresses
    FOR INSERT
    WITH CHECK (auth.uid() = user_id);

-- Users can update their own saved addresses
CREATE POLICY "Users can update their own saved addresses"
    ON saved_addresses
    FOR UPDATE
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

-- Users can delete their own saved addresses
CREATE POLICY "Users can delete their own saved addresses"
    ON saved_addresses
    FOR DELETE
    USING (auth.uid() = user_id);

-- =====================================================
-- TRIGGER FOR UPDATED_AT
-- =====================================================

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_saved_addresses_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger to automatically update updated_at
CREATE TRIGGER trigger_update_saved_addresses_updated_at
    BEFORE UPDATE ON saved_addresses
    FOR EACH ROW
    EXECUTE FUNCTION update_saved_addresses_updated_at();

-- =====================================================
-- HELPER FUNCTIONS
-- =====================================================

-- Get saved addresses for current user sorted by usage/creation
CREATE OR REPLACE FUNCTION get_user_saved_addresses()
RETURNS TABLE (
    id UUID,
    label VARCHAR,
    emoji VARCHAR,
    full_address TEXT,
    latitude DOUBLE PRECISION,
    longitude DOUBLE PRECISION,
    house_number VARCHAR,
    street VARCHAR,
    barangay VARCHAR,
    city VARCHAR,
    province VARCHAR,
    created_at TIMESTAMPTZ
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        sa.id,
        sa.label,
        sa.emoji,
        sa.full_address,
        sa.latitude,
        sa.longitude,
        sa.house_number,
        sa.street,
        sa.barangay,
        sa.city,
        sa.province,
        sa.created_at
    FROM saved_addresses sa
    WHERE sa.user_id = auth.uid()
    ORDER BY sa.created_at DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =====================================================
-- SAMPLE DATA (OPTIONAL - FOR TESTING)
-- =====================================================

-- Uncomment to insert sample data for testing

INSERT INTO saved_addresses (user_id, label, emoji, full_address, latitude, longitude, street, barangay, city)
VALUES 
    ((SELECT id FROM auth.users LIMIT 1), 'Home', '🏠', '123 Main Street, Barangay San Antonio, Manila', 14.5995, 120.9842, 'Main Street', 'San Antonio', 'Manila'),
    ((SELECT id FROM auth.users LIMIT 1), 'Office', '🏢', '456 Business Ave, Makati City', 14.5547, 121.0244, 'Business Ave', 'Poblacion', 'Makati'),
    ((SELECT id FROM auth.users LIMIT 1), 'Warehouse A', '📦', '789 Industrial Road, Quezon City', 14.6760, 121.0437, 'Industrial Road', 'Bagumbayan', 'Quezon City');

