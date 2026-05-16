// supabase/functions/toggle_lock/index.ts
//
// UPDATED: Now forwards any extra policy fields (allow_factory_reset,
// allow_admin_removal) directly in the FCM **data** object — NOT in the
// notification body — so the customer app handles it silently in the
// background without the user needing to tap any notification.

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const FCM_SERVER_KEY = Deno.env.get("FCM_SERVER_KEY")!;

serve(async (req: Request) => {
  try {
    const body = await req.json();
    const { device_id, action, ...extraFields } = body;

    if (!device_id || !action) {
      return new Response(JSON.stringify({ error: "device_id and action required" }), {
        status: 400,
        headers: { "Content-Type": "application/json" },
      });
    }

    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY);

    // ── 1. Update DB for LOCK / UNLOCK ─────────────────────────────────────────
    if (action === "LOCK") {
      await supabase.from("devices").update({ is_locked: true }).eq("id", device_id);
    } else if (action === "UNLOCK") {
      await supabase.from("devices").update({ is_locked: false }).eq("id", device_id);
    }
    // APPLY_POLICIES: DB is already updated by admin app before calling this function

    // ── 2. Get FCM token ────────────────────────────────────────────────────────
    const { data: device, error } = await supabase
      .from("devices")
      .select("fcm_token")
      .eq("id", device_id)
      .single();

    if (error || !device?.fcm_token) {
      return new Response(JSON.stringify({ error: "Device or FCM token not found" }), {
        status: 404,
        headers: { "Content-Type": "application/json" },
      });
    }

    // ── 3. Build FCM data payload ───────────────────────────────────────────────
    // IMPORTANT: Use ONLY "data" key (no "notification" key).
    // This makes it a DATA-ONLY message → delivered silently to background handler.
    // The customer app processes it automatically without the user tapping anything.
    const fcmData: Record<string, string> = {
      action,
      // Forward any extra policy fields sent by the admin app
      ...Object.fromEntries(
        Object.entries(extraFields).map(([k, v]) => [k, String(v)])
      ),
    };

    // ── 4. Send FCM via HTTP v1 (Legacy API) ────────────────────────────────────
    const fcmPayload = {
      to: device.fcm_token,
      // NO "notification" key → pure data message → silent background delivery
      data: fcmData,
      android: {
        priority: "high", // wake device even in Doze mode
      },
    };

    const fcmResponse = await fetch("https://fcm.googleapis.com/fcm/send", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `key=${FCM_SERVER_KEY}`,
      },
      body: JSON.stringify(fcmPayload),
    });

    const fcmResult = await fcmResponse.json();

    return new Response(
      JSON.stringify({ success: true, fcm: fcmResult }),
      { status: 200, headers: { "Content-Type": "application/json" } }
    );
  } catch (err) {
    return new Response(JSON.stringify({ error: String(err) }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }
});
