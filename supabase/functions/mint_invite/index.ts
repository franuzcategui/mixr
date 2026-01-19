import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { errorResponse, jsonResponse } from "../_shared/http.ts";
import { getUserId, supabaseAdmin } from "../_shared/supabase.ts";

function randomToken() {
  return crypto.randomUUID().replace(/-/g, "");
}

serve(async (request) => {
  if (request.method !== "POST") {
    return errorResponse("METHOD_NOT_ALLOWED", 405);
  }

  let userId: string;
  try {
    userId = await getUserId(request);
  } catch (error) {
    return errorResponse((error as Error).message, 401);
  }

  let payload: {
    name?: string;
    timezone?: string;
    swipe_start_at?: string;
    swipe_end_at?: string;
    is_paid?: boolean;
  } = {};

  try {
    payload = await request.json();
  } catch {
    // Optional body, ignore if missing.
  }

  const now = new Date();
  const swipeStartAt = payload.swipe_start_at ?? new Date(now.getTime() - 5 * 60 * 1000).toISOString();
  const swipeEndAt = payload.swipe_end_at ?? new Date(now.getTime() + 2 * 60 * 60 * 1000).toISOString();
  const name = payload.name ?? "Test Event";
  const timezone = payload.timezone ?? "UTC";
  const isPaid = payload.is_paid ?? true;

  const { data: event, error: eventError } = await supabaseAdmin
    .from("events")
    .insert({
      name,
      created_by: userId,
      timezone,
      swipe_start_at: swipeStartAt,
      swipe_end_at: swipeEndAt,
      is_paid: isPaid,
      is_test_mode: !isPaid,
    })
    .select("id, name, swipe_start_at, swipe_end_at, timezone, is_paid, is_test_mode, test_mode_attendee_cap")
    .single();

  if (eventError || !event) {
    return errorResponse("EVENT_CREATE_FAILED", 500);
  }

  const token = randomToken();
  const { error: inviteError } = await supabaseAdmin.from("invites").insert({
    event_id: event.id,
    token,
    created_by: userId,
  });

  if (inviteError) {
    return errorResponse("INVITE_CREATE_FAILED", 500);
  }

  return jsonResponse({
    invite_token: token,
    event_id: event.id,
    event_name: event.name,
    swipe_start_at: event.swipe_start_at,
    swipe_end_at: event.swipe_end_at,
    timezone: event.timezone,
    is_paid: event.is_paid,
    is_test_mode: event.is_test_mode,
    test_mode_attendee_cap: event.test_mode_attendee_cap,
  });
});
