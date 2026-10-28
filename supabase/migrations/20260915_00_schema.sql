-- Enable PostGIS extension for spatial data
CREATE EXTENSION IF NOT EXISTS postgis WITH SCHEMA extensions;

-- Custom Types
CREATE TYPE public.blood_group AS ENUM (
  'A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'
);

CREATE TYPE public.urgency_level AS ENUM (
  'Critical', 'Within 24 Hours'
);

CREATE TYPE public.request_status AS ENUM (
  'Open', 'Fulfilled', 'Expired'
);

-- Profiles Table (Users/Donors)
CREATE TABLE public.profiles (
  id UUID REFERENCES auth.users(id) ON DELETE CASCADE PRIMARY KEY,
  full_name TEXT NOT NULL,
  phone_number TEXT UNIQUE NOT NULL,
  blood_group public.blood_group NOT NULL,
  location extensions.geometry(Point, 4326), -- Longitude, Latitude
  city TEXT,
  is_available_for_donation BOOLEAN DEFAULT true,
  last_donation_date TIMESTAMPTZ,
  cooldown_ends_at TIMESTAMPTZ,
  total_donations_count INTEGER DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create a spatial index for fast 10km radius queries
CREATE INDEX profiles_location_idx ON public.profiles USING GIST (location);

-- Emergency Requests Table
CREATE TABLE public.emergency_requests (
  request_id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  requester_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
  patient_name TEXT NOT NULL,
  hospital_name TEXT NOT NULL,
  required_blood_group public.blood_group NOT NULL,
  units_needed INTEGER NOT NULL CHECK (units_needed > 0),
  urgency_level public.urgency_level NOT NULL,
  location extensions.geometry(Point, 4326) NOT NULL,
  status public.request_status DEFAULT 'Open',
  accepted_by UUID[] DEFAULT '{}', -- Array of User IDs who accepted
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Set up Row Level Security (RLS)
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.emergency_requests ENABLE ROW LEVEL SECURITY;

-- Profiles Policies
-- Users can read their own profile, including their phone number
CREATE POLICY "Users can read own profile" ON public.profiles
  FOR SELECT USING (auth.uid() = id);

-- Users can update their own profile
CREATE POLICY "Users can update own profile" ON public.profiles
  FOR UPDATE USING (auth.uid() = id);

-- Service role can read/manage all profiles (e.g., for Edge Functions matching donors)
CREATE POLICY "Service role can manage all profiles" ON public.profiles
  USING (true)
  WITH CHECK (true);

-- Emergency Requests Policies
-- Anyone authenticated can create a request
CREATE POLICY "Authenticated users can create requests" ON public.emergency_requests
  FOR INSERT WITH CHECK (auth.uid() = requester_id);

-- Anyone authenticated can read active requests
CREATE POLICY "Authenticated users can view requests" ON public.emergency_requests
  FOR SELECT USING (auth.role() = 'authenticated');

-- Requester can update their own request
CREATE POLICY "Requester can update request" ON public.emergency_requests
  FOR UPDATE USING (auth.uid() = requester_id);
