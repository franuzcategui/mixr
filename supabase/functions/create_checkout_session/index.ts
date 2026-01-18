import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import Stripe from "https://esm.sh/stripe@12.18.0?target=deno";
import { errorResponse, jsonResponse } from "../_shared/http.ts";
import { getUserId, supabaseAdmin } from "../_shared/supabase.ts";

const stripeSecretKey = Deno.env.get("STRIPE_SECRET_KEY");
const stripePriceId = Deno.env.get("STRIPE_PRICE_ID");
const appUrl = Deno.env.get("APP_URL");

if (!stripeSecretKey || !stripePriceId || !appUrl) {
  throw new Error("Missing STRIPE_SECRET_KEY, STRIPE_PRICE_ID, or APP_URL");
}

const stripe = new Stripe(stripeSecretKey, {
  apiVersion: "2023-10-16",
});

const SQL = {
  selectAdmin: `
    select 1
    from public.events e
    where e.id = $1 and e.created_by = $2
    union all
    select 1
    from public.event_members em
    where em.event_id = $1
      and em.user_id = $2
      and em.role = 'admin'
      and em.status = 'joined'
  `,
  updateEvent: `
    update public.events
    set checkout_session_id = $2
    where id = $1
  `,
};

serve(async (request) => {
  if (request.method !== "POST") {
    return errorResponse("METHOD_NOT_ALLOWED", 405);
  }

  let eventId: string | undefined;
  try {
    const payload = await request.json();
    eventId = payload?.event_id;
  } catch {
    return errorResponse("INVALID_JSON", 400);
  }

  if (!eventId) {
    return errorResponse("MISSING_EVENT_ID", 400);
  }

  let userId: string;
  try {
    userId = await getUserId(request);
  } catch (error) {
    return errorResponse((error as Error).message, 401);
  }

  const { data: eventOwner, error: ownerError } = await supabaseAdmin
    .from("events")
    .select("id")
    .eq("id", eventId)
    .eq("created_by", userId)
    .maybeSingle();

  if (ownerError) {
    return errorResponse("ADMIN_CHECK_FAILED", 500);
  }

  let isAdmin = Boolean(eventOwner);

  if (!isAdmin) {
    const { data: adminMember, error: memberError } = await supabaseAdmin
      .from("event_members")
      .select("event_id")
      .eq("event_id", eventId)
      .eq("user_id", userId)
      .eq("role", "admin")
      .eq("status", "joined")
      .maybeSingle();

    if (memberError) {
      return errorResponse("ADMIN_CHECK_FAILED", 500);
    }

    isAdmin = Boolean(adminMember);
  }

  if (!isAdmin) {
    return errorResponse("FORBIDDEN", 403);
  }

  const session = await stripe.checkout.sessions.create({
    mode: "payment",
    line_items: [{ price: stripePriceId, quantity: 1 }],
    success_url: `${appUrl}/payment-success?event_id=${eventId}`,
    cancel_url: `${appUrl}/payment-cancelled?event_id=${eventId}`,
    metadata: { event_id: eventId },
  });

  if (!session.url) {
    return errorResponse("CHECKOUT_URL_MISSING", 500);
  }

  const { error: updateError } = await supabaseAdmin
    .from("events")
    .update({ checkout_session_id: session.id })
    .eq("id", eventId);

  if (updateError) {
    return errorResponse("CHECKOUT_STORE_FAILED", 500);
  }

  return jsonResponse({ checkout_url: session.url });
});
