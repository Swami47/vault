-- ============================================================
-- Vault — Row Level Security Policies
-- Every table is locked down: users can only access their own rows
-- ============================================================

-- Enable RLS on ALL tables
ALTER TABLE public.photos ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.albums ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.album_photos ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.tags ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.photo_tags ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.audit_log ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_storage ENABLE ROW LEVEL SECURITY;

-- Photos: user can only access own photos
CREATE POLICY "Users can manage own photos" ON public.photos
    FOR ALL TO authenticated
    USING (user_id = (SELECT auth.uid()))
    WITH CHECK (user_id = (SELECT auth.uid()));

-- Albums: user can only access own albums
CREATE POLICY "Users can manage own albums" ON public.albums
    FOR ALL TO authenticated
    USING (user_id = (SELECT auth.uid()))
    WITH CHECK (user_id = (SELECT auth.uid()));

-- Album photos: scoped via album ownership
CREATE POLICY "Users can manage own album photos" ON public.album_photos
    FOR ALL TO authenticated
    USING (album_id IN (SELECT id FROM public.albums WHERE user_id = (SELECT auth.uid())))
    WITH CHECK (album_id IN (SELECT id FROM public.albums WHERE user_id = (SELECT auth.uid())));

-- Tags: user can only access own tags
CREATE POLICY "Users can manage own tags" ON public.tags
    FOR ALL TO authenticated
    USING (user_id = (SELECT auth.uid()))
    WITH CHECK (user_id = (SELECT auth.uid()));

-- Photo tags: scoped via photo ownership
CREATE POLICY "Users can manage own photo tags" ON public.photo_tags
    FOR ALL TO authenticated
    USING (photo_id IN (SELECT id FROM public.photos WHERE user_id = (SELECT auth.uid())))
    WITH CHECK (photo_id IN (SELECT id FROM public.photos WHERE user_id = (SELECT auth.uid())));

-- Audit log: read-only access to own entries
CREATE POLICY "Users can read own audit log" ON public.audit_log
    FOR SELECT TO authenticated
    USING (user_id = (SELECT auth.uid()));

-- Audit log: insert own entries (for service role, but also allow authenticated just in case)
CREATE POLICY "Service can insert audit log" ON public.audit_log
    FOR INSERT TO authenticated
    WITH CHECK (user_id = (SELECT auth.uid()));

-- User storage: read own row
CREATE POLICY "Users can read own storage" ON public.user_storage
    FOR SELECT TO authenticated
    USING (user_id = (SELECT auth.uid()));

-- User storage: insert/update own row
CREATE POLICY "Users can manage own storage" ON public.user_storage
    FOR ALL TO authenticated
    USING (user_id = (SELECT auth.uid()))
    WITH CHECK (user_id = (SELECT auth.uid()));
