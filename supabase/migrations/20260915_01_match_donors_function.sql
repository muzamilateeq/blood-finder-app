-- Function to get matching donors within a certain radius (default 10km)
CREATE OR REPLACE FUNCTION public.get_nearby_donors(
  req_blood_group public.blood_group,
  req_location extensions.geometry(Point, 4326),
  radius_meters DOUBLE PRECISION DEFAULT 10000
) RETURNS TABLE (
  donor_id UUID,
  distance_meters DOUBLE PRECISION
) LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  RETURN QUERY
  SELECT 
    p.id as donor_id,
    ST_Distance(p.location::geography, req_location::geography) as distance_meters
  FROM public.profiles p
  WHERE 
    p.is_available_for_donation = true
    AND p.id != auth.uid() -- Don't notify the requester
    -- Blood compatibility logic
    AND p.blood_group IN (
      SELECT unnest(
        CASE req_blood_group
          WHEN 'A+' THEN ARRAY['A+', 'A-', 'O+', 'O-']::public.blood_group[]
          WHEN 'A-' THEN ARRAY['A-', 'O-']::public.blood_group[]
          WHEN 'B+' THEN ARRAY['B+', 'B-', 'O+', 'O-']::public.blood_group[]
          WHEN 'B-' THEN ARRAY['B-', 'O-']::public.blood_group[]
          WHEN 'AB+' THEN ARRAY['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-']::public.blood_group[]
          WHEN 'AB-' THEN ARRAY['AB-', 'A-', 'B-', 'O-']::public.blood_group[]
          WHEN 'O+' THEN ARRAY['O+', 'O-']::public.blood_group[]
          WHEN 'O-' THEN ARRAY['O-']::public.blood_group[]
        END
      )
    )
    -- PostGIS ST_DWithin calculates fast distance checks using the GiST index
    AND ST_DWithin(p.location::geography, req_location::geography, radius_meters)
  ORDER BY distance_meters ASC
  LIMIT 50; -- Prevent spamming thousands of users at once, limit to 50 nearest
END;
$$;
