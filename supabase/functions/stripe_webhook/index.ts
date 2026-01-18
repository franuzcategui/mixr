import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import Stripe from "https://esm.sh/stripe@12.18.0?target=deno";
import { errorResponse, jsonResponse } from "../_shared/http.ts";
import { supabaseAdmin } from "../_shared/supabase.ts";

const stripeSecretKey = Deno.env.get("STRIPE_SECRET_KEY");
const stripeWebhookSecret = Deno.env.get("STRIPE_WEBHOOK_SECRET");

if (!stripeSecretKey || !stripeWebhookSecret) {
  throw new Error("Missing STRIPE_SECRET_KEY or STRIPE_WEBHOOK_SECRET");
}

const stripe = new Stripe(stripeSecretKey, {
  apiVersion: "2023-10-16",
});

const SQL = {
  updateEvent: `
    update public.events
    set is_paid = true,
        is_test_mode = false,
        paid_at = now()
    where id = $1
  `,
};

serve(async (request) => {
  if (request.method !== "POST") {
    return errorResponse("METHOD_NOT_ALLOWED", 405);
  }

  const signature = request.headers.get("stripe-signature");
  if (!signature) {
    return errorResponse("MISSING_SIGNATURE", 400);
  }

  const payload = await request.text();

  let event: Stripe.Event;
  try {
    event = stripe.webhooks.constructEvent(payload, signature, stripeWebhookSecret);
  } catch {
    return errorResponse("INVALID_SIGNATURE", 400);
  }

  if (event.type === "checkout.session.completed") {
    const session = event.data.object as Stripe.Checkout.Session;
    const eventId = session.metadata?.event_id;

    if (!eventId) {
      return errorResponse("MISSING_EVENT_ID", 400);
    }

    const { error: updateError } = await supabaseAdmin
      .from("events")
      .update({
        is_paid: true,
        is_test_mode: false,
        paid_at: new Date().toISOString(),
      })
      .eq("id", eventId);

    if (updateError) {
      return errorResponse("EVENT_UPDATE_FAILED", 500);
    }
  }

  return jsonResponse({ received: true });
});
