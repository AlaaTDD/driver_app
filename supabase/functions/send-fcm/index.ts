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

  const { user_id, title, body, data } = await req.json();
  if (!user_id || !title || !body) {
    return new Response(JSON.stringify({ error: "Missing required fields" }), {
      status: 400,
      headers: { "Content-Type": "application/json" },
    });
  }

  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );

  const { data: user } = await supabase
    .from("users")
    .select("fcm_token")
    .eq("id", user_id)
    .single();

  if (!user?.fcm_token) {
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

  const messagePayload: any = {
    token: user.fcm_token,
    data: Object.fromEntries(
      Object.entries(data || {}).map(([k, v]) => [k, String(v)]),
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
