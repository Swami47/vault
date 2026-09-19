# Vault — Secure Personal Photo Storage

A production-grade, full-stack private photo vault with defense-in-depth security.

## Architecture

```
┌──────────────────────────────────────────────────────────────┐
│                    FRONTEND (Vercel)                          │
│  Next.js 15 · App Router · TypeScript · Tailwind CSS v4      │
│  @supabase/ssr — auth handshake + session cookies            │
│  All data/storage ops → FastAPI backend via JWT              │
└─────────────────────────┬────────────────────────────────────┘
                          │  HTTPS + Bearer JWT
                          ▼
┌──────────────────────────────────────────────────────────────┐
│                    BACKEND (Render)                           │
│  FastAPI · Python 3.12 · Pydantic v2                         │
│  JWT verification (local, HS256)                             │
│  EXIF stripping · Thumbnail generation · Signed URLs         │
│  Rate limiting (SlowAPI) · Audit logging                     │
└─────────────────────────┬────────────────────────────────────┘
                          │  Supabase SDK (service_role key)
                          ▼
┌──────────────────────────────────────────────────────────────┐
│                    SUPABASE (Cloud)                           │
│  Auth — email/password + magic link                          │
│  Postgres — 7 tables, all with RLS                           │
│  Storage — private bucket "vault-photos", AES-256 at rest    │
└──────────────────────────────────────────────────────────────┘
```

## Auth Flow

1. User signs up / logs in via Supabase Auth (browser-side, `@supabase/ssr`)
2. Session stored in httpOnly cookies (managed by `@supabase/ssr`)
3. Next.js middleware refreshes session on every request
4. Frontend extracts `access_token` and sends it as `Authorization: Bearer <token>` to FastAPI
5. FastAPI verifies JWT locally using `PyJWT` + project JWT secret (sub-ms, no remote call)
6. FastAPI uses `service_role` key for Supabase operations — RLS still enforced via explicit `user_id` filters

## Local Development Setup

### Prerequisites
- Node.js 18+
- Python 3.12+
- A Supabase project (free tier works)

### 1. Supabase Setup
1. Create a new Supabase project at [supabase.com](https://supabase.com)
2. Go to **SQL Editor** and run the migrations in order:
   - `supabase/migrations/001_initial_schema.sql`
   - `supabase/migrations/002_rls_policies.sql`
   - `supabase/migrations/003_storage_bucket.sql`
   - `supabase/migrations/004_indexes.sql`
3. Go to **Storage** → Create a new bucket called `vault-photos` with **Public** set to **OFF**
4. Collect your credentials from **Settings → API**:
   - Project URL
   - Anon key (public)
   - Service role key (secret!)
   - JWT secret (under Project Settings → API → JWT Settings)

### 2. Backend
```bash
cd backend
python -m venv venv
venv\Scripts\activate  # Windows
# source venv/bin/activate  # Mac/Linux
pip install -r requirements.txt

# Copy and fill in env vars
cp .env.example .env
# Edit .env with your Supabase credentials

# Run
uvicorn main:app --reload --port 8000
```

### 3. Frontend
```bash
cd frontend
npm install

# Copy and fill in env vars
cp .env.example .env.local
# Edit .env.local with your Supabase URL and anon key

# Run
npm run dev
```

Visit `http://localhost:3000`

## Database Schema (RLS Wiring)

| Table | RLS Policy | Scope |
|-------|-----------|-------|
| `photos` | `user_id = auth.uid()` | Full CRUD |
| `albums` | `user_id = auth.uid()` | Full CRUD |
| `album_photos` | via album ownership | Full CRUD |
| `tags` | `user_id = auth.uid()` | Full CRUD |
| `photo_tags` | via photo ownership | Full CRUD |
| `audit_log` | `user_id = auth.uid()` | Read-only |
| `user_storage` | `user_id = auth.uid()` | Read + manage own |
| `storage.objects` | folder path = `auth.uid()` | Full CRUD |

Every table has RLS enabled. Even though the backend uses `service_role` (which bypasses RLS), all queries explicitly filter by `user_id` as a defense-in-depth measure.

## Environment Variables

### Backend (`backend/.env`)
| Variable | Description |
|----------|-------------|
| `SUPABASE_URL` | Your Supabase project URL |
| `SUPABASE_SERVICE_ROLE_KEY` | Service role key (secret, server-only) |
| `SUPABASE_JWT_SECRET` | JWT secret for local token verification |
| `ALLOWED_ORIGINS` | Frontend URL (CORS) |
| `STORAGE_BUCKET` | Storage bucket name (`vault-photos`) |

### Frontend (`frontend/.env.local`)
| Variable | Description |
|----------|-------------|
| `NEXT_PUBLIC_SUPABASE_URL` | Your Supabase project URL |
| `NEXT_PUBLIC_SUPABASE_ANON_KEY` | Anon key (public, safe for frontend) |
| `NEXT_PUBLIC_API_URL` | Backend API URL |

## Deployment

### Frontend → Vercel
1. Push to GitHub
2. Import in Vercel
3. Set environment variables
4. Deploy

### Backend → Render
1. Push to GitHub
2. Create Web Service in Render
3. Select Docker runtime, point to `backend/Dockerfile`
4. Set environment variables
5. Deploy
