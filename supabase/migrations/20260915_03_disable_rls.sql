-- Disable RLS temporarily to allow Firebase Auth users to interact with the database
-- Note: In a production app with a hybrid setup, you would typically use a Supabase Custom JWT, 
-- or a service role in an Edge Function, rather than fully disabling RLS.

ALTER TABLE public.profiles DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.emergency_requests DISABLE ROW LEVEL SECURITY;

-- If you want to keep RLS enabled but allow anonymous access (since Firebase users 
-- are "anonymous" to Supabase without a custom JWT mapping):
-- CREATE POLICY "Allow public read/write to profiles" ON public.profiles FOR ALL USING (true) WITH CHECK (true);
-- CREATE POLICY "Allow public read/write to requests" ON public.emergency_requests FOR ALL USING (true) WITH CHECK (true);
