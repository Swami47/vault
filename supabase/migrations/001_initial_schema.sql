-- ============================================================
-- Vault — Initial Schema
-- Run in Supabase SQL Editor
-- ============================================================

-- Photos table
CREATE TABLE IF NOT EXISTS public.photos (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    filename TEXT NOT NULL,
    storage_path TEXT NOT NULL,
    thumbnail_path TEXT NOT NULL,
    file_size BIGINT NOT NULL,
    mime_type TEXT NOT NULL,
    width INTEGER,
    height INTEGER,
    exif_stripped BOOLEAN DEFAULT true,
    is_trashed BOOLEAN DEFAULT false,
    trashed_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- Albums table
CREATE TABLE IF NOT EXISTS public.albums (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    description TEXT,
    cover_photo_id UUID,
    photo_count INTEGER DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- Album-Photo junction
CREATE TABLE IF NOT EXISTS public.album_photos (
    album_id UUID NOT NULL REFERENCES public.albums(id) ON DELETE CASCADE,
    photo_id UUID NOT NULL REFERENCES public.photos(id) ON DELETE CASCADE,
    added_at TIMESTAMPTZ DEFAULT now(),
    PRIMARY KEY (album_id, photo_id)
);

-- Tags
CREATE TABLE IF NOT EXISTS public.tags (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT now(),
    UNIQUE(user_id, name)
);

-- Photo-Tag junction
CREATE TABLE IF NOT EXISTS public.photo_tags (
    photo_id UUID NOT NULL REFERENCES public.photos(id) ON DELETE CASCADE,
    tag_id UUID NOT NULL REFERENCES public.tags(id) ON DELETE CASCADE,
    PRIMARY KEY (photo_id, tag_id)
);

-- Audit log
CREATE TABLE IF NOT EXISTS public.audit_log (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    action TEXT NOT NULL,
    resource_type TEXT NOT NULL,
    resource_id UUID,
    metadata JSONB DEFAULT '{}',
    created_at TIMESTAMPTZ DEFAULT now()
);

-- User storage quota tracking
CREATE TABLE IF NOT EXISTS public.user_storage (
    user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    bytes_used BIGINT DEFAULT 0,
    quota_bytes BIGINT DEFAULT 5368709120,
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- Add foreign key for album cover photo (deferred because photos table must exist first)
ALTER TABLE public.albums
    ADD CONSTRAINT fk_cover_photo
    FOREIGN KEY (cover_photo_id) REFERENCES public.photos(id) ON DELETE SET NULL;
