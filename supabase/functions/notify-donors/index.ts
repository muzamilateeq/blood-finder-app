import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

// You must configure this secret in Supabase:
// supabase secrets set FCM_SERVER_KEY="your-server-key"
const FCM_SERVER_KEY = Deno.env.get('FCM_SERVER_KEY')

serve(async (req) => {
  try {
    const payload = await req.json()
    
    // The payload.record represents the newly inserted emergency_requests row
    const record = payload.record

    // Verify this is a new INSERT request that is still 'Open'
    if (payload.type !== 'INSERT' || record.status !== 'Open') {
      return new Response(JSON.stringify({ message: 'Not an open insert, ignoring' }), { status: 200 })
    }

    // Initialize Supabase Client with the Service Role key (bypasses RLS)
    const supabaseUrl = Deno.env.get('SUPABASE_URL')
    const supabaseKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')
    
    if (!supabaseUrl || !supabaseKey || !FCM_SERVER_KEY) {
      throw new Error('Missing environment variables')
    }

    const supabase = createClient(supabaseUrl, supabaseKey)

    // Call the PostgreSQL function to find matching donors within 10km
    const { data: donors, error } = await supabase.rpc('get_nearby_donors', {
      req_blood_group: record.required_blood_group,
      req_location: record.location,
      radius_meters: 10000 // 10 km
    })

    if (error) {
      console.error('Error fetching donors:', error)
      throw error
    }

    if (!donors || donors.length === 0) {
      console.log('No donors found in a 10km radius.')
      return new Response(JSON.stringify({ message: 'No donors to notify' }), { status: 200 })
    }

    // Extract donor IDs
    const donorIds = donors.map((d: any) => d.donor_id)
    
    // Retrieve the FCM tokens for these donors. 
    // Assuming a `user_fcm_tokens` table exists.
    const { data: tokensData, error: tokensError } = await supabase
      .from('user_fcm_tokens')
      .select('fcm_token')
      .in('user_id', donorIds)

    if (tokensError) {
      console.error('Error fetching tokens:', tokensError)
      throw tokensError
    }

    const tokens = tokensData?.map((t: any) => t.fcm_token) || []

    if (tokens.length === 0) {
      console.log('Donors found, but no FCM tokens available.')
      return new Response(JSON.stringify({ message: 'No tokens found' }), { status: 200 })
    }

    // Construct the high-priority FCM Payload
    const fcmPayload = {
      registration_ids: tokens,
      notification: {
        title: `URGENT: ${record.required_blood_group} Blood Needed!`,
        body: `${record.patient_name} needs ${record.units_needed} units at ${record.hospital_name}. Tap to help.`,
        sound: 'default', // Ensures notification sound plays
      },
      data: {
        requestId: record.request_id,
        urgency: record.urgency_level,
        hospitalName: record.hospital_name,
        action: 'OPEN_REQUEST'
      },
      priority: 'high'
    }

    // Dispatch request to Firebase Cloud Messaging
    const fcmRes = await fetch('https://fcm.googleapis.com/fcm/send', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `key=${FCM_SERVER_KEY}`
      },
      body: JSON.stringify(fcmPayload)
    })

    const fcmResult = await fcmRes.json()
    console.log('FCM Result:', fcmResult)

    return new Response(JSON.stringify({ message: 'Notifications dispatched', result: fcmResult }), { status: 200 })

  } catch (err: any) {
    console.error('Webhook error:', err)
    return new Response(JSON.stringify({ error: err.message }), { status: 500 })
  }
})
