// @ts-nocheck
// Deno/Supabase Edge Function — not compiled by the local TS language server.
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { importPKCS8, SignJWT } from "https://esm.sh/jose@4.14.4";

/**
 * Generate a short-lived OAuth2 access token for FCM HTTP v1
 * using the Firebase service account (JSON) stored in the
 * FIREBASE_SERVICE_ACCOUNT environment secret.
 */
async function getFcmAccessToken(): Promise<string | null> {
  const raw = Deno.env.get("FIREBASE_SERVICE_ACCOUNT");
  if (!raw) {
    console.error("FIREBASE_SERVICE_ACCOUNT not set");
    return null;
  }

  let sa: any;
  try {
    sa = JSON.parse(raw);
  } catch {
    console.error("FIREBASE_SERVICE_ACCOUNT is not valid JSON");
    return null;
  }

  if (!sa.private_key || !sa.client_email) {
    console.error("FIREBASE_SERVICE_ACCOUNT missing private_key or client_email");
    return null;
  }

  try {
    const privateKey = await importPKCS8(sa.private_key, "RS256");
    const now = Math.floor(Date.now() / 1000);

    const jwt = await new SignJWT({
      iss: sa.client_email,
      sub: sa.client_email,
      scope: "https://www.googleapis.com/auth/firebase.messaging",
      aud: "https://oauth2.googleapis.com/token",
      iat: now,
      exp: now + 3600,
    })
      .setProtectedHeader({ alg: "RS256", typ: "JWT" })
      .sign(privateKey);

    const tokenRes = await fetch("https://oauth2.googleapis.com/token", {
      method: "POST",
      headers: { "Content-Type": "application/x-www-form-urlencoded" },
      body: new URLSearchParams({
        grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
        assertion: jwt,
      }),
    });

    const tokenData = await tokenRes.json();
    if (!tokenData.access_token) {
      console.error("OAuth token exchange failed:", tokenData);
      return null;
    }
    return tokenData.access_token as string;
  } catch (e) {
    console.error("JWT signing failed:", e);
    return null;
  }
}

serve(async (req) => {
  if (req.method !== "POST") {
    return new Response(JSON.stringify({ error: "Method not allowed" }), {
      status: 405,
      headers: { "Content-Type": "application/json" },
    });
  }

  // ─── Auth verification: sender must be the authenticated user ───
  const authHeader = req.headers.get("Authorization");
  if (!authHeader) {
    return new Response(JSON.stringify({ error: "Missing Authorization header" }), {
      status: 401,
      headers: { "Content-Type": "application/json" },
    });
  }

  const supabaseAuth = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_ANON_KEY")!,
  );

  const { data: { user: senderUser }, error: authError } = await supabaseAuth.auth.getUser(
    authHeader.replace("Bearer ", ""),
  );

  if (authError || !senderUser) {
    return new Response(JSON.stringify({ error: "Unauthorized" }), {
      status: 401,
      headers: { "Content-Type": "application/json" },
    });
  }

  const { user_id, title, body, data: payloadData } = await req.json();

  console.log(`FCM send attempt: sender=${senderUser.id}, target=${user_id}`);
  if (!user_id || !title || !body) {
    return new Response(JSON.stringify({ error: "Missing required fields" }), {
      status: 400,
      headers: { "Content-Type": "application/json" },
    });
  }

  // ─── Security: verify sender has a relationship with receiver ───
  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );

  // Allow if they share an active trip OR have exchanged direct messages
  const { data: sharedTrip, error: tripErr } = await supabase
    .from("trips")
    .select("id")
    .in("status", ["accepted", "in_progress", "arrived", "picked_up", "pending"])
    .or(`and(user_id.eq.${senderUser.id},driver_id.eq.${user_id}),and(user_id.eq.${user_id},driver_id.eq.${senderUser.id})`)
    .limit(1)
    .maybeSingle();

  const { data: directMsg, error: msgErr } = await supabase
    .from("messages")
    .select("id")
    .or(`and(sender_id.eq.${senderUser.id},receiver_id.eq.${user_id}),and(sender_id.eq.${user_id},receiver_id.eq.${senderUser.id})`)
    .is("trip_id", null)
    .limit(1)
    .maybeSingle();

  if (!sharedTrip && !directMsg) {
    console.warn(`FCM rejected: sender=${senderUser.id} has no relationship with target=${user_id}`);
    return new Response(JSON.stringify({ error: "no_relationship" }), {
      status: 403,
      headers: { "Content-Type": "application/json" },
    });
  }

  const { data: recipientUser } = await supabase
    .from("users")
    .select("fcm_token")
    .eq("id", user_id)
    .single();

  if (!recipientUser?.fcm_token) {
    return new Response(JSON.stringify({ error: "no_fcm_token" }), {
      status: 200,
      headers: { "Content-Type": "application/json" },
    });
  }

  const projectId = Deno.env.get("FIREBASE_PROJECT_ID");
  if (!projectId) {
    return new Response(
      JSON.stringify({ error: "missing_firebase_project_id" }),
      { status: 500, headers: { "Content-Type": "application/json" } },
    );
  }

  const accessToken = await getFcmAccessToken();
  if (!accessToken) {
    return new Response(
      JSON.stringify({ error: "missing_firebase_access_token" }),
      { status: 500, headers: { "Content-Type": "application/json" } },
    );
  }

  // For ride_offer: enrich the data payload with full trip details
  // so the background isolate doesn't need to query Supabase (no auth session there)
  let enrichedData = { ...(data || {}) };

  if (data?.type === "ride_offer" && data?.trip_id) {
    try {
      const { data: trip } = await supabase
        .from("trips")
        .select("*, user:users!trips_user_id_fkey(name)")
        .eq("id", data.trip_id)
        .single();

      if (trip) {
        enrichedData = {
          ...enrichedData,
          pickup_address: trip.pickup_address || "",
          destination_address: trip.destination_address || "",
          distance_km: String(trip.distance_km || 0),
          price: String(trip.price || 0),
          vehicle_type: trip.vehicle_type || "car",
          pickup_lat: String(trip.pickup_lat || 0),
          pickup_lng: String(trip.pickup_lng || 0),
          destination_lat: String(trip.destination_lat || 0),
          destination_lng: String(trip.destination_lng || 0),
          passenger_name: trip.user?.name || "",
          created_at: trip.created_at || "",
        };
        console.log("Enriched ride_offer payload with trip details for", data.trip_id);
      }
    } catch (e) {
      console.error("Failed to enrich ride_offer payload:", e);
    }
  }

  const messagePayload: any = {
    token: recipientUser.fcm_token,
    data: Object.fromEntries(
      Object.entries(enrichedData).map(([k, v]) => [k, String(v)]),
    ),
    android: {
      priority: "high",
    },
    apns: {
      payload: {
        aps: {
          "content-available": 1,
        },
      },
    },
  };

  // ⚠️ CRITICAL FIX: If it's a ride offer, DO NOT include the notification block.
  // Including 'notification' causes FCM to handle it via the system tray when in background,
  // preventing the Flutter background handler (and our custom Overlay/Alarm) from executing!
  // By sending it as a Data-Only message, Android wakes up the app in the background.
  if (data?.type !== "ride_offer" && data?.notification_type !== "ride_offer") {
    messagePayload.notification = { title, body };
  } else {
    // Pass title and body inside data just in case the app needs them
    messagePayload.data.title = title || "";
    messagePayload.data.body = body || "";
  }

  const fcmResponse = await fetch(
    `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`,
    {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${accessToken}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({ message: messagePayload }),
    },
  );

  const result = await fcmResponse.json();

  if (result.error?.status === "UNREGISTERED" || result.error?.code === 404) {
    await supabase.from("users").update({ fcm_token: null }).eq("id", user_id);
  }

  return new Response(
    JSON.stringify({ ok: true, fcmResponse: result }),
    { status: 200, headers: { "Content-Type": "application/json" } },
  );
});
