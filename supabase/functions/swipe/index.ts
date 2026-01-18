import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { errorResponse, jsonResponse } from "../_shared/http.ts";
import { getUserId, supabaseAdmin } from "../_shared/supabase.ts";

const SQL = {
  selectMember: `
    select status
    from public.event_members
    where event_id = $1 and user_id = $2
  `,
  selectEvent: `
    select swipe_start_at, swipe_end_at, is_paid, is_test_mode, test_mode_attendee_cap, match_expires_days
    from public.events
    where id = $1
  `,
  countJoined: `
    select count(*)::int as joined_count
    from public.event_members
    where event_id = $1 and status = 'joined'
  `,
  insertSwipe: `
    insert into public.swipes (event_id, swiper_id, swiped_id, direction)
    values ($1, $2, $3, $4)
    on conflict (event_id, swiper_id, swiped_id) do nothing
  `,
  selectReciprocal: `
    select 1
    from public.swipes
    where event_id = $1
      and swiper_id = $2
      and swiped_id = $3
      and direction = 'right'
    limit 1
  `,
  insertMatch: `
    insert into public.matches (event_id, user_a, user_b, expires_at)
    values ($1, $2, $3, $4)
    on conflict (event_id, user_low, user_high) do nothing
    returning id
  `,
};

serve(async (request) => {
  if (request.method !== "POST") {
    return errorResponse("METHOD_NOT_ALLOWED", 405);
  }

  let eventId: string | undefined;
  let swipedId: string | undefined;
  let direction: "left" | "right" | undefined;

  try {
    const payload = await request.json();
    eventId = payload?.event_id;
    swipedId = payload?.swiped_id;
    direction = payload?.direction;
  } catch {
    return errorResponse("INVALID_JSON", 400);
  }

  if (!eventId || !swipedId || (direction !== "left" && direction !== "right")) {
    return errorResponse("INVALID_INPUT", 400);
  }

  let userId: string;
  try {
    userId = await getUserId(request);
  } catch (error) {
    return errorResponse((error as Error).message, 401);
  }

  if (userId === swipedId) {
    return errorResponse("INVALID_TARGET", 400);
  }

  const { data: memberRow, error: memberError } = await supabaseAdmin
    .from("event_members")
    .select("status")
    .eq("event_id", eventId)
    .eq("user_id", userId)
    .maybeSingle();

  if (memberError) {
    return errorResponse("MEMBERSHIP_LOOKUP_FAILED", 500);
  }

  if (!memberRow) {
    return errorResponse("NOT_MEMBER", 403);
  }

  if (memberRow.status === "blocked") {
    return errorResponse("BLOCKED", 403);
  }

  const { data: eventRow, error: eventError } = await supabaseAdmin
    .from("events")
    .select(
      "swipe_start_at, swipe_end_at, is_paid, is_test_mode, test_mode_attendee_cap, match_expires_days",
    )
    .eq("id", eventId)
    .maybeSingle();

  if (eventError) {
    return errorResponse("EVENT_LOOKUP_FAILED", 500);
  }

  if (!eventRow) {
    return errorResponse("EVENT_NOT_FOUND", 404);
  }

  const { count: joinedCount, error: countError } = await supabaseAdmin
    .from("event_members")
    .select("event_id", { count: "exact", head: true })
    .eq("event_id", eventId)
    .eq("status", "joined");

  if (countError) {
    return errorResponse("COUNT_FAILED", 500);
  }

  const isUnlocked = eventRow.is_paid ||
    (eventRow.is_test_mode && (joinedCount ?? 0) <= eventRow.test_mode_attendee_cap);

  if (!isUnlocked) {
    return errorResponse("EVENT_LOCKED", 403);
  }

  const now = new Date();
  if (now < new Date(eventRow.swipe_start_at) || now > new Date(eventRow.swipe_end_at)) {
    return errorResponse("OUTSIDE_WINDOW", 403);
  }

  const { error: swipeError } = await supabaseAdmin
    .from("swipes")
    .insert({
      event_id: eventId,
      swiper_id: userId,
      swiped_id: swipedId,
      direction,
    });

  if (swipeError && swipeError.code !== "23505") {
    return errorResponse("SWIPE_INSERT_FAILED", 500);
  }

  if (swipeError?.code === "23505") {
    return errorResponse("ALREADY_SWIPED", 409);
  }

  let matched = false;
  let matchId: string | undefined;

  if (direction === "right") {
    const { data: reciprocalRow, error: reciprocalError } = await supabaseAdmin
      .from("swipes")
      .select("event_id")
      .eq("event_id", eventId)
      .eq("swiper_id", swipedId)
      .eq("swiped_id", userId)
      .eq("direction", "right")
      .maybeSingle();

    if (reciprocalError) {
      return errorResponse("RECIPROCAL_LOOKUP_FAILED", 500);
    }

    if (reciprocalRow) {
      const expiresAt = new Date(eventRow.swipe_end_at);
      expiresAt.setUTCDate(expiresAt.getUTCDate() + eventRow.match_expires_days);

      const { data: matchRow, error: matchError } = await supabaseAdmin
        .from("matches")
        .insert({
          event_id: eventId,
          user_a: userId,
          user_b: swipedId,
          expires_at: expiresAt.toISOString(),
        })
        .select("id")
        .maybeSingle();

      if (matchError && matchError.code !== "23505") {
        return errorResponse("MATCH_CREATE_FAILED", 500);
      }

      if (matchRow) {
        matched = true;
        matchId = matchRow.id;
      } else if (matchError?.code === "23505") {
        const { data: existingMatch, error: existingError } = await supabaseAdmin
          .from("matches")
          .select("id")
          .eq("event_id", eventId)
          .or(
            `and(user_a.eq.${userId},user_b.eq.${swipedId}),and(user_a.eq.${swipedId},user_b.eq.${userId})`,
          )
          .maybeSingle();

        if (existingError) {
          return errorResponse("MATCH_LOOKUP_FAILED", 500);
        }

        if (existingMatch) {
          matched = true;
          matchId = existingMatch.id;
        }
      }
    }
  }

  return jsonResponse({ ok: true, matched, match_id: matchId });
});
