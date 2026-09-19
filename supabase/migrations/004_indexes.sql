-- ============================================================
-- Vault — Performance Indexes
-- ============================================================

CREATE INDEX IF NOT EXISTS idx_photos_user_id ON public.photos(user_id);
CREATE INDEX IF NOT EXISTS idx_photos_user_created ON public.photos(user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_photos_user_trashed ON public.photos(user_id, is_trashed);
CREATE INDEX IF NOT EXISTS idx_albums_user_id ON public.albums(user_id);
CREATE INDEX IF NOT EXISTS idx_audit_log_user_created ON public.audit_log(user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_tags_user_id ON public.tags(user_id);
CREATE INDEX IF NOT EXISTS idx_album_photos_album ON public.album_photos(album_id);
CREATE INDEX IF NOT EXISTS idx_album_photos_photo ON public.album_photos(photo_id);
CREATE INDEX IF NOT EXISTS idx_photo_tags_photo ON public.photo_tags(photo_id);
CREATE INDEX IF NOT EXISTS idx_photo_tags_tag ON public.photo_tags(tag_id);
