-- ============================================================
-- Vault — Storage Bucket Setup
-- Create via Supabase Dashboard > Storage, then apply this RLS policy
-- ============================================================

-- NOTE: Create the bucket "vault-photos" in the Supabase Dashboard first,
-- with "Public" set to OFF (private bucket).
-- Then run this policy:

-- Storage RLS: users can only access files in their own folder
CREATE POLICY "Users can manage own storage objects" ON storage.objects
    FOR ALL TO authenticated
    USING (
        bucket_id = 'vault-photos' AND
        (storage.foldername(name))[1] = (SELECT auth.uid())::TEXT
    )
    WITH CHECK (
        bucket_id = 'vault-photos' AND
        (storage.foldername(name))[1] = (SELECT auth.uid())::TEXT
    );
