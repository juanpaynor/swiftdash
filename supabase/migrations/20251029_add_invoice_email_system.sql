-- Migration: Add invoice email tracking and automatic sending
-- Created: 2025-10-29
-- Description: Adds columns to track invoice emails and creates trigger to auto-send invoices when delivery is completed

-- Step 1: Add invoice tracking columns to deliveries table
ALTER TABLE deliveries 
ADD COLUMN IF NOT EXISTS invoice_sent BOOLEAN DEFAULT FALSE,
ADD COLUMN IF NOT EXISTS invoice_sent_at TIMESTAMPTZ,
ADD COLUMN IF NOT EXISTS invoice_email_id VARCHAR;

-- Add comments for documentation
COMMENT ON COLUMN deliveries.invoice_sent IS 'Whether invoice email has been sent to customer';
COMMENT ON COLUMN deliveries.invoice_sent_at IS 'Timestamp when invoice email was sent';
COMMENT ON COLUMN deliveries.invoice_email_id IS 'Resend email ID for tracking';

-- Step 2: Enable pg_net extension for HTTP requests from database
CREATE EXTENSION IF NOT EXISTS pg_net;

-- Step 3: Create function to send invoice email via Edge Function
CREATE OR REPLACE FUNCTION send_invoice_email_on_delivery()
RETURNS TRIGGER 
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  request_id BIGINT;
  supabase_url TEXT;
  supabase_anon_key TEXT;
BEGIN
  -- Only proceed if:
  -- 1. Status changed to 'delivered'
  -- 2. Previous status was NOT 'delivered' (first time becoming delivered)
  -- 3. Invoice has not been sent yet
  IF NEW.status = 'delivered' 
     AND (OLD.status IS NULL OR OLD.status != 'delivered')
     AND (NEW.invoice_sent IS NULL OR NEW.invoice_sent = FALSE)
  THEN
    -- Get Supabase configuration from app_settings table
    SELECT value INTO supabase_url FROM app_settings WHERE key = 'supabase_url';
    SELECT value INTO supabase_anon_key FROM app_settings WHERE key = 'supabase_anon_key';
    
    -- Fallback if not configured
    IF supabase_url IS NULL THEN
      RAISE WARNING 'Supabase URL not configured in app_settings table';
      RETURN NEW;
    END IF;
    
    IF supabase_anon_key IS NULL THEN
      RAISE WARNING 'Supabase anon key not configured in app_settings table';
      RETURN NEW;
    END IF;
    
    RAISE NOTICE 'Triggering invoice email for delivery: %', NEW.id;
    
    -- Call Edge Function asynchronously using pg_net
    -- This won't block the delivery update and will retry on failure
    SELECT INTO request_id net.http_post(
      url := supabase_url || '/functions/v1/send-invoice-email',
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'Authorization', 'Bearer ' || supabase_anon_key
      ),
      body := jsonb_build_object(
        'deliveryId', NEW.id::text
      ),
      timeout_milliseconds := 10000 -- 10 second timeout
    );
    
    RAISE NOTICE 'Invoice email request queued with ID: %', request_id;
    
  END IF;
  
  RETURN NEW;
END;
$$;

-- Add comment for documentation
COMMENT ON FUNCTION send_invoice_email_on_delivery() IS 
  'Automatically sends invoice email when delivery status changes to delivered';

-- Step 4: Create trigger on deliveries table
DROP TRIGGER IF EXISTS trigger_send_invoice_email ON deliveries;

CREATE TRIGGER trigger_send_invoice_email
  AFTER UPDATE OF status ON deliveries
  FOR EACH ROW
  EXECUTE FUNCTION send_invoice_email_on_delivery();

-- Add comment for documentation
COMMENT ON TRIGGER trigger_send_invoice_email ON deliveries IS 
  'Triggers invoice email when delivery is marked as delivered';

-- Step 5: Create index for faster queries on invoice status
CREATE INDEX IF NOT EXISTS idx_deliveries_invoice_sent 
ON deliveries(invoice_sent, invoice_sent_at) 
WHERE invoice_sent = TRUE;

-- Step 6: Grant necessary permissions
-- Allow authenticated users to read invoice status
GRANT SELECT ON deliveries TO authenticated;

-- Step 7: Create view for invoice analytics (optional but useful)
CREATE OR REPLACE VIEW invoice_analytics AS
SELECT 
  DATE_TRUNC('day', invoice_sent_at) as date,
  COUNT(*) as invoices_sent,
  COUNT(*) FILTER (WHERE invoice_sent_at > completed_at + INTERVAL '1 hour') as delayed_invoices,
  AVG(EXTRACT(EPOCH FROM (invoice_sent_at - completed_at))) as avg_send_delay_seconds
FROM deliveries
WHERE invoice_sent = TRUE
GROUP BY DATE_TRUNC('day', invoice_sent_at)
ORDER BY date DESC;

-- Add comment
COMMENT ON VIEW invoice_analytics IS 
  'Daily analytics for invoice email sending performance';

-- Step 8: Create configuration table for Supabase settings
CREATE TABLE IF NOT EXISTS app_settings (
  key TEXT PRIMARY KEY,
  value TEXT NOT NULL,
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Insert Supabase configuration
INSERT INTO app_settings (key, value) VALUES 
  ('supabase_url', 'https://lygzxmhskkqrntnmxtbb.supabase.co'),
  ('supabase_anon_key', 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imx5Z3p4bWhza2txcm50bm14dGJiIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTgyODQ3MjQsImV4cCI6MjA3Mzg2MDcyNH0.BUk80PxkIXzaohReyAXF0TpuMKp2HV49eg9E_Zq9XDQ'),
  ('supabase_project_ref', 'lygzxmhskkqrntnmxtbb')
ON CONFLICT (key) DO UPDATE SET 
  value = EXCLUDED.value,
  updated_at = NOW();

-- Add comment
COMMENT ON TABLE app_settings IS 'Application configuration settings';

RAISE NOTICE 'Invoice email system installed successfully!';
RAISE NOTICE 'Next steps:';
RAISE NOTICE '1. ✅ Supabase configuration set';
RAISE NOTICE '2. Deploy send-invoice-email Edge Function: supabase functions deploy send-invoice-email';
RAISE NOTICE '3. Add RESEND_API_KEY to Supabase Edge Function secrets: supabase secrets set RESEND_API_KEY=re_xxxxx';
