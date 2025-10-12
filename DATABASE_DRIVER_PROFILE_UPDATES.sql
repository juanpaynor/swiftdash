-- Add missing plate number field to driver_profiles table
-- Date: October 11, 2025

-- Add plate_number field to driver_profiles table
ALTER TABLE public.driver_profiles 
ADD COLUMN IF NOT EXISTS plate_number VARCHAR(20);

-- Add comment for documentation
COMMENT ON COLUMN public.driver_profiles.plate_number IS 'Vehicle plate/license plate number';

-- Optional: Add index for faster searches by plate number
CREATE INDEX IF NOT EXISTS idx_driver_profiles_plate_number 
ON public.driver_profiles(plate_number);

-- Also add profile_picture_url if it doesn't exist (for driver photos)
ALTER TABLE public.driver_profiles 
ADD COLUMN IF NOT EXISTS profile_picture_url TEXT;

COMMENT ON COLUMN public.driver_profiles.profile_picture_url IS 'URL to driver profile picture/photo';

-- Update any existing test data (optional)
-- You can uncomment these if you want to add sample data
-- UPDATE public.driver_profiles SET plate_number = 'ABC-1234' WHERE plate_number IS NULL LIMIT 1;
-- UPDATE public.driver_profiles SET profile_picture_url = 'https://example.com/driver1.jpg' WHERE profile_picture_url IS NULL LIMIT 1;

-- Verify the changes
-- SELECT column_name, data_type, is_nullable 
-- FROM information_schema.columns 
-- WHERE table_name = 'driver_profiles' 
-- ORDER BY column_name;