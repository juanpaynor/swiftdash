# Supabase Storage Setup for Chat Images

## Quick Setup Instructions

### 1. Create Storage Bucket

Go to your Supabase Dashboard → Storage → Create a new bucket

**Bucket Configuration:**
- **Name:** `chat-images`
- **Public bucket:** ✅ YES (checked)
- **File size limit:** 5 MB (recommended)
- **Allowed MIME types:** `image/jpeg, image/png, image/gif, image/webp`

### 2. Set Bucket Policies

After creating the bucket, go to **Policies** tab and add these policies:

> **⚠️ IMPORTANT:** Copy ONLY the SQL code (not the headers). Run each policy separately.

#### Policy 1: Allow Uploads (Authenticated Users)
```sql
CREATE POLICY "Allow authenticated users to upload chat images"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (
  bucket_id = 'chat-images' 
  AND (storage.foldername(name))[1] = 'deliveries'
);
```

#### Policy 2: Allow Public Read Access
```sql
CREATE POLICY "Allow public read access to chat images"
ON storage.objects FOR SELECT
TO public
USING (bucket_id = 'chat-images');
```

#### Policy 3: Allow Users to Delete Their Own Images
```sql
CREATE POLICY "Allow users to delete their own chat images"
ON storage.objects FOR DELETE
TO authenticated
USING (
  bucket_id = 'chat-images'
  AND (storage.foldername(name))[1] = 'deliveries'
);
```

---

### Quick Copy-Paste (All 3 Policies at Once)

Copy this entire block and run in Supabase SQL Editor:

```sql
-- Policy 1: Allow authenticated users to upload
CREATE POLICY "Allow authenticated users to upload chat images"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (
  bucket_id = 'chat-images' 
  AND (storage.foldername(name))[1] = 'deliveries'
);

-- Policy 2: Allow public read access
CREATE POLICY "Allow public read access to chat images"
ON storage.objects FOR SELECT
TO public
USING (bucket_id = 'chat-images');

-- Policy 3: Allow users to delete their own images
CREATE POLICY "Allow users to delete their own chat images"
ON storage.objects FOR DELETE
TO authenticated
USING (
  bucket_id = 'chat-images'
  AND (storage.foldername(name))[1] = 'deliveries'
);
```

### 3. Verify Setup

Test the bucket by uploading a test image via the Supabase Dashboard.

### 4. File Structure

Images will be stored with this path structure:
```
chat-images/
  └── deliveries/
      └── chat/
          └── {deliveryId}/
              ├── {timestamp}_{uuid}.jpg
              ├── {timestamp}_{uuid}.png
              └── ...
```

### 5. Alternative: SQL Script

Run this in Supabase SQL Editor:

```sql
-- Create the chat-images bucket (if not exists via UI)
INSERT INTO storage.buckets (id, name, public)
VALUES ('chat-images', 'chat-images', true)
ON CONFLICT (id) DO NOTHING;

-- Policy: Allow authenticated users to upload
CREATE POLICY "Allow authenticated users to upload chat images"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (
  bucket_id = 'chat-images' 
  AND (storage.foldername(name))[1] = 'deliveries'
);

-- Policy: Allow public read
CREATE POLICY "Allow public read access to chat images"
ON storage.objects FOR SELECT
TO public
USING (bucket_id = 'chat-images');

-- Policy: Allow users to delete their own images
CREATE POLICY "Allow users to delete their own chat images"
ON storage.objects FOR DELETE
TO authenticated
USING (
  bucket_id = 'chat-images'
  AND (storage.foldername(name))[1] = 'deliveries'
);
```

## Usage in App

The app automatically:
1. Picks image from gallery
2. Compresses to max 1920x1920, 85% quality
3. Uploads to `chat-images/deliveries/chat/{deliveryId}/{timestamp}_{uuid}.{ext}`
4. Gets public URL
5. Sends URL via Ably chat
6. Displays image in message bubble
7. Allows tap to view fullscreen with zoom

## Troubleshooting

### "Failed to upload image"
- ✅ Check bucket exists: `chat-images`
- ✅ Check bucket is public
- ✅ Check policies are set correctly
- ✅ Verify user is authenticated

### "Image not loading"
- ✅ Check public URL is correct
- ✅ Verify image uploaded successfully in Supabase Storage dashboard
- ✅ Check network connection

### "Permission denied"
- ✅ Verify policies allow authenticated users to upload
- ✅ Check user authentication status
- ✅ Ensure file path matches policy conditions

## Cleanup (Optional)

Auto-cleanup old images (48+ hours):

```sql
-- Create a database function to delete old images
CREATE OR REPLACE FUNCTION delete_old_chat_images()
RETURNS void AS $$
BEGIN
  DELETE FROM storage.objects
  WHERE bucket_id = 'chat-images'
    AND created_at < NOW() - INTERVAL '48 hours';
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Schedule it to run daily (requires pg_cron extension)
SELECT cron.schedule(
  'delete-old-chat-images',
  '0 2 * * *', -- Run at 2 AM daily
  'SELECT delete_old_chat_images();'
);
```

## Security Notes

- ✅ Public bucket allows anyone to view images (required for driver app)
- ✅ Only authenticated users can upload
- ✅ File paths are scoped to deliveries
- ✅ Images auto-delete after 48 hours (if cleanup function enabled)
- ✅ Max file size: 5 MB
- ⚠️ No profanity/content filtering (add if needed)

---

**Setup Status:** 🔴 NOT CONFIGURED
**Action Required:** Create `chat-images` bucket in Supabase Dashboard
