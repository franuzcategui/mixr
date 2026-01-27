import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { errorResponse, jsonResponse } from "../_shared/http.ts";
import { getUserId, supabaseAdmin } from "../_shared/supabase.ts";

function randomToken() {
  return crypto.randomUUID().replace(/-/g, "");
}

serve(async (request) => {
  console.log('mint_invite request', { request });
  if (request.method !== "POST") {
    return errorResponse("METHOD_NOT_ALLOWED", 405);
  }

  const authHeader = request.headers.get("authorization");
  const tokenLength = authHeader?.replace("Bearer ", "").trim().length ?? 0;
  console.log("mint_invite auth header", {
    hasAuth: Boolean(authHeader),
    tokenLength,
  });

  let userId: string;
  try {
    userId = await getUserId(request);
  } catch (error) {
    const message = (error as Error).message;
    console.log("mint_invite auth error", { error: message });
    return errorResponse(message, 401);
  }

  let payload: {
    name?: string;
    timezone?: string;
    swipe_start_at?: string;
    swipe_end_at?: string;
    is_paid?: boolean;
    max_seed_attendees?: number;
  } = {};

  try {
    payload = await request.json();
  } catch {
    // Optional body, ignore if missing.
  }

  const now = new Date();
  const swipeStartAt = new Date(
    payload.swipe_start_at ?? now.getTime() - 5 * 60 * 1000,
  ).toISOString();
  const swipeEndAt = new Date(
    payload.swipe_end_at ?? now.getTime() + 2 * 60 * 60 * 1000,
  ).toISOString();
  const name = payload.name ?? "Test Event";
  const timezone = payload.timezone ?? "UTC";
  const isPaid = payload.is_paid ?? true;
  const maxSeeds = Number.isFinite(payload.max_seed_attendees)
    ? Math.max(0, Math.floor(payload.max_seed_attendees as number))
    : 10;

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

  const { error: creatorError } = await supabaseAdmin
    .from("event_members")
    .upsert(
      {
        event_id: event.id,
        user_id: userId,
        role: "admin",
        status: "joined",
      },
      { onConflict: "event_id,user_id" },
    );

  if (creatorError) {
    return errorResponse("MEMBERSHIP_CREATE_FAILED", 500);
  }

  const seedCount = Math.floor(Math.random() * (maxSeeds + 1));
  let seededCount = 0;

  if (seedCount > 0) {
    const { data: seedProfiles, error: seedError } = await supabaseAdmin
      .from("profiles")
      .select("user_id")
      .neq("user_id", userId)
      .limit(seedCount);

    if (seedError || !seedProfiles) {
      return errorResponse("SEED_LOOKUP_FAILED", 500);
    }

    const seedIds = [...seedProfiles.map((row) => row.user_id as string)];
    for (let i = seedIds.length - 1; i > 0; i -= 1) {
      const j = Math.floor(Math.random() * (i + 1));
      [seedIds[i], seedIds[j]] = [seedIds[j], seedIds[i]];
    }

    for (const seedUserId of seedIds) {
      const { error: seedInsertError } = await supabaseAdmin
        .from("event_members")
        .upsert(
          {
            event_id: event.id,
            user_id: seedUserId,
            role: "attendee",
            status: "joined",
          },
          { onConflict: "event_id,user_id", ignoreDuplicates: true },
        );

      if (!seedInsertError) {
        seededCount += 1;
      }
    }

    if (seededCount == 0) {
      return errorResponse("SEED_FAILED", 500);
    }
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
    seeded_count: seededCount,
  });
});
