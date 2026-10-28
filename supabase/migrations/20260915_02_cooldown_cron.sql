-- Create a function to check and reset cooldowns
CREATE OR REPLACE FUNCTION public.reset_donor_cooldowns()
RETURNS void LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  -- Reset is_available_for_donation to true if cooldown has passed
  UPDATE public.profiles
  SET 
    is_available_for_donation = true,
    cooldown_ends_at = NULL
  WHERE 
    is_available_for_donation = false 
    AND cooldown_ends_at IS NOT NULL 
    AND cooldown_ends_at <= NOW();
    
  -- In a full implementation, you could also insert into a notifications table here
  -- to let users know their cooldown is over.
END;
$$;

-- IMPORTANT: Supabase uses pg_cron for scheduling tasks.
-- If pg_cron is enabled for your project, you can uncomment and run the following
-- to schedule this function to run every day at midnight.
-- SELECT cron.schedule(
--   'reset_cooldowns_job',
--   '0 0 * * *',
--   'SELECT public.reset_donor_cooldowns();'
-- );
