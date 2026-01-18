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
  selectMember: `
    select role, status
    from public.event_members
    where event_id = $1 and user_id = $2
  `,
  updateMemberStatus: `
    update public.event_members
    set status = 'joined'
    where event_id = $1 and user_id = $2
  `,
  insertMember: `
    insert into public.event_members (event_id, user_id, role, status)
    values ($1, $2, 'attendee', 'joined')
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

  let userId: string;
  try {
    userId = await getUserId(request);
  } catch (error) {
    return errorResponse((error as Error).message, 401);
  }

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

  const { data: existingMember, error: memberLookupError } = await supabaseAdmin
    .from("event_members")
    .select("role, status")
    .eq("event_id", inviteRow.event_id)
    .eq("user_id", userId)
    .maybeSingle();

  if (memberLookupError) {
    return errorResponse("MEMBERSHIP_LOOKUP_FAILED", 500);
  }

  if (existingMember) {
    if (existingMember.status === "blocked") {
      return errorResponse("BLOCKED", 403);
    }

    const { error: memberUpdateError } = await supabaseAdmin
      .from("event_members")
      .update({ status: "joined" })
      .eq("event_id", inviteRow.event_id)
      .eq("user_id", userId);

    if (memberUpdateError) {
      return errorResponse("MEMBERSHIP_UPDATE_FAILED", 500);
    }
  } else {
    const { error: memberInsertError } = await supabaseAdmin
      .from("event_members")
      .insert({
        event_id: inviteRow.event_id,
        user_id: userId,
        role: "attendee",
        status: "joined",
      });

    if (memberInsertError) {
      return errorResponse("MEMBERSHIP_INSERT_FAILED", 500);
    }
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
