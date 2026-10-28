-- ============================================================================
-- Migration: Add readable location columns & Chat Messages Table
-- Organizes all user and communication data into clear, understandable sections
-- ============================================================================

-- 1. Ensure Profiles table has human-readable coordinate columns alongside PostGIS
ALTER TABLE public.profiles 
  ADD COLUMN IF NOT EXISTS latitude NUMERIC,
  ADD COLUMN IF NOT EXISTS longitude NUMERIC,
  ADD COLUMN IF NOT EXISTS address TEXT;

-- Add helpful descriptions to make Supabase Table Editor easy to understand
COMMENT ON TABLE public.profiles IS 'All verified blood donors and patient user accounts';
COMMENT ON COLUMN public.profiles.full_name IS 'Section 1: User Identity - Full legal or display name';
COMMENT ON COLUMN public.profiles.phone_number IS 'Section 1: User Identity - Verified contact phone number';
COMMENT ON COLUMN public.profiles.blood_group IS 'Section 2: Medical - Blood type (A+, A-, B+, B-, AB+, AB-, O+, O-)';
COMMENT ON COLUMN public.profiles.is_available_for_donation IS 'Section 2: Medical - Active donation readiness flag';
COMMENT ON COLUMN public.profiles.cooldown_ends_at IS 'Section 2: Medical - 90-day cooldown period expiration';
COMMENT ON COLUMN public.profiles.city IS 'Section 3: Location - Primary city or district (e.g. Lahore)';
COMMENT ON COLUMN public.profiles.latitude IS 'Section 3: Location - GPS Latitude decimal degrees';
COMMENT ON COLUMN public.profiles.longitude IS 'Section 3: Location - GPS Longitude decimal degrees';
COMMENT ON COLUMN public.profiles.location IS 'Section 3: Location - PostGIS Geometry Point for 10km spatial queries';

-- 2. Chat Messages Table (Stores all in-app real-time conversations)
CREATE TABLE IF NOT EXISTS public.chat_messages (
  id TEXT PRIMARY KEY,
  request_id TEXT NOT NULL,
  sender_id TEXT NOT NULL,
  sender_name TEXT NOT NULL,
  text TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Enable fast lookups by request_id
CREATE INDEX IF NOT EXISTS idx_chat_messages_request_id ON public.chat_messages(request_id);

-- Disable RLS on chat_messages for seamless Firebase/Supabase hybrid integration
ALTER TABLE public.chat_messages DISABLE ROW LEVEL SECURITY;

-- 3. FCM Device Push Tokens Table (For background notifications)
CREATE TABLE IF NOT EXISTS public.user_fcm_tokens (
  user_id TEXT PRIMARY KEY,
  fcm_token TEXT NOT NULL,
  device_type TEXT, -- 'ios' | 'android'
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE public.user_fcm_tokens DISABLE ROW LEVEL SECURITY;
