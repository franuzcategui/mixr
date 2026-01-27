import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { errorResponse, jsonResponse } from "../_shared/http.ts";
import { getUserId, supabaseAdmin } from "../_shared/supabase.ts";

const SQL = {
  selectInvite: `
    select i.event_id, i.expires_at, e.name, e.swipe_start_at, e.swipe_end_at, e.timezone,
           e.is_paid, e.is_test_mode, e.test_mode_attendee_cap
    from public.invites i
    join public.events e on e.id = i.event_id
    where i.token = $1
  `,
  upsertMember: `
    insert into public.event_members (event_id, user_id, role, status)
    values ($1, $2, 'attendee', 'joined')
    on conflict (event_id, user_id) do update
      set status = 'joined'
    returning event_id
  `,
};

serve(async (request) => {
  if (request.method !== "POST") {
    return errorResponse("METHOD_NOT_ALLOWED", 405);
  }

  let token: string | undefined;
  try {
    const payload = await request.json();
    token = payload?.token;
  } catch {
    return errorResponse("INVALID_JSON", 400);
  }

  if (!token) {
    return errorResponse("MISSING_TOKEN", 400);
  }

  const authHeader = request.headers.get("Authorization");
  const tokenLength = authHeader?.replace("Bearer ", "").trim().length ?? 0;
  console.log("join_event auth header", {
    hasAuth: Boolean(authHeader),
    tokenLength,
  });

  let userId: string;
  try {
    userId = await getUserId(request);
  } catch (error) {
    const message = (error as Error).message;
    console.log("join_event auth error", { error: message });
    return jsonResponse({ error: "INVALID_AUTH", details: message }, 401);
  }

  console.log("join_event auth check", { userId });

  const { data: inviteRow, error: inviteError } = await supabaseAdmin
    .from("invites")
    .select(
      "event_id, expires_at, events(name, swipe_start_at, swipe_end_at, timezone, is_paid, is_test_mode, test_mode_attendee_cap)",
    )
    .eq("token", token)
    .maybeSingle();

  if (inviteError) {
    return errorResponse("INVITE_LOOKUP_FAILED", 500);
  }

  if (!inviteRow) {
    return errorResponse("INVALID_INVITE", 404);
  }

  if (inviteRow.expires_at && new Date(inviteRow.expires_at) < new Date()) {
    return errorResponse("INVITE_EXPIRED", 410);
  }

  const { error: memberError } = await supabaseAdmin
    .from("event_members")
    .upsert(
      {
        event_id: inviteRow.event_id,
        user_id: userId,
        role: "attendee",
        status: "joined",
      },
      { onConflict: "event_id,user_id" },
    );

  if (memberError) {
    return errorResponse("MEMBERSHIP_UPSERT_FAILED", 500);
  }

  const event = inviteRow.events;
  return jsonResponse({
    event_id: inviteRow.event_id,
    event_name: event.name,
    swipe_start_at: event.swipe_start_at,
    swipe_end_at: event.swipe_end_at,
    timezone: event.timezone,
    is_paid: event.is_paid,
    is_test_mode: event.is_test_mode,
    test_mode_attendee_cap: event.test_mode_attendee_cap,
  });
});
