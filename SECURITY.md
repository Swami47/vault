# Vault — Security Model

This document describes the threat model, security controls, and known limitations of the Vault application.

## Threat Model

### What Vault protects against

| Threat | Control |
|--------|---------|
| **Unauthorized API access** | JWT verification on every route; tokens validated locally using HS256 + project secret |
| **Cross-user data access** | Row-Level Security (RLS) on all Postgres tables; storage paths scoped by user_id |
| **Metadata leakage (EXIF/GPS)** | Server-side stripping via Pillow pixel-data-copy (removes ALL metadata including embedded thumbnails); toggleable, default ON |
| **Brute-force auth attacks** | Rate limiting via SlowAPI (5 req/min on auth endpoints per IP) |
| **Upload abuse** | Rate limiting (30 req/min), file type validation (JPEG/PNG/WebP/HEIC only), size limit (50MB per file), quota enforcement |
| **Data at rest exposure** | Supabase Storage AES-256 encryption at rest; private bucket (no public URLs) |
| **Data in transit exposure** | HTTPS everywhere (Vercel + Render enforce TLS); Supabase connections are TLS |
| **URL-based unauthorized access** | Signed URLs expire in 5 minutes; generated server-side after ownership verification |
| **Orphaned deleted files** | Secure delete removes both storage blobs and database rows; audit-logged |
| **Session hijacking** | httpOnly cookies via @supabase/ssr; no sensitive tokens in localStorage |
| **Service key exposure** | Supabase service_role key exists only in backend env vars; never in frontend bundle |

### What Vault does NOT protect against

| Limitation | Explanation |
|-----------|-------------|
| **Compromised device** | If your device is compromised, an attacker with access to the browser session can view your photos. This is true of any web application. |
| **Supabase infrastructure compromise** | Vault trusts Supabase for storage encryption and auth. A breach of Supabase infrastructure would expose data. |
| **Server-side admin access** | Anyone with access to the Supabase project dashboard or service_role key can bypass RLS. Protect these credentials. |
| **Client-side encryption** | Photos are NOT encrypted client-side before upload. The trade-off: server-side thumbnail generation and EXIF stripping require access to the raw image bytes. See "Encryption Decision" below. |
| **Zero-knowledge architecture** | The backend can see photo contents (needed for thumbnail generation). This is not a zero-knowledge system. |

## Encryption Decision

### Approach: Server-side Supabase AES-256 at rest

We chose **not** to implement client-side encryption for these reasons:

1. **Thumbnail generation requires unencrypted images.** The server generates 400px WebP thumbnails for fast grid browsing. With client-side encryption, the server would receive opaque blobs and couldn't create thumbnails.

2. **EXIF stripping requires unencrypted images.** Removing GPS/camera metadata happens server-side via Pillow. Encrypted blobs would preserve the metadata inside the ciphertext.

3. **Key management UX burden.** Client-side encryption requires either:
   - Deriving a key from the user's password (which means password changes invalidate all encrypted photos), or
   - A separate encryption key (which the user must store somewhere — if lost, all photos are permanently unrecoverable).

4. **Supabase's built-in encryption is strong.** AES-256 at rest, TLS in transit, private buckets, short-lived signed URLs — this provides robust protection against the primary threats (unauthorized access, data at rest exposure).

### If you need zero-knowledge encryption

For a zero-knowledge architecture, you would need to:
- Encrypt in the browser using a key derived from the user's credentials
- Generate thumbnails client-side before encryption
- Store the key derivation salt server-side, the key never leaves the browser
- Accept that server-side search and metadata queries on photo content would be impossible

This is a valid architecture for maximum security but significantly increases complexity and degrades UX. The current approach prioritizes strong, practical security without crippling the user experience.

## Security Controls — Implementation Details

### Authentication
- **Protocol:** Supabase Auth (email/password + magic link)
- **Session:** httpOnly cookies via `@supabase/ssr` (not localStorage)
- **Token verification:** Local JWT decode with PyJWT (HS256, audience="authenticated")
- **Token lifetime:** Managed by Supabase (default 1 hour, auto-refresh via middleware)

### Authorization
- **Database:** RLS enabled on ALL 7 tables + storage.objects
- **Application:** Every service method includes explicit `user_id` filter (defense-in-depth)
- **Storage:** Path-based scoping (`{user_id}/originals/...`, `{user_id}/thumbnails/...`)

### Rate Limiting
| Endpoint | Limit | Key |
|----------|-------|-----|
| Auth (signup/login/reset) | 5/minute | Per IP |
| Photo upload | 30/minute | Per user |
| General API | 120/minute | Per user |

### Audit Trail
Every sensitive action is logged to the `audit_log` table:
- `upload`, `view`, `delete`, `download`, `trash`, `restore`, `permanent_delete`
- `album_create`, `album_delete`, `album_update`

Each entry includes: user_id, action, resource_type, resource_id, metadata (filename, file_size), timestamp.

The user can view their own audit log in the Activity page.

### Secure Delete
Deleting a photo:
1. Removes the original file from Supabase Storage
2. Removes the thumbnail from Supabase Storage
3. Deletes all photo-tag and album-photo junction rows
4. Deletes the photo metadata row from Postgres
5. Updates the user's storage usage counter
6. Writes a `permanent_delete` audit log entry

No orphaned files or phantom database rows remain.

### EXIF Metadata Stripping
- **Method:** Pillow pixel-data-copy (creates a new image from raw pixel data, discarding all metadata)
- **Coverage:** EXIF, IPTC, XMP, embedded thumbnails, maker notes
- **Default:** ON (user can toggle OFF per-upload if they want to preserve metadata)
- **Processing:** Server-side, before the image is stored in Supabase Storage
