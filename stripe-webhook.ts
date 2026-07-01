// Supabase Edge Function: stripe-webhook
// ---------------------------------------------------------------------------
// Deploy target: Supabase Dashboard -> Edge Functions -> Create a function
//   -> name it "stripe-webhook" -> paste this whole file -> Deploy.
//
// What it does: verifies the request really came from Stripe, then — on a
// checkout.session.completed event (fires when someone pays through one of
// your pasted Payment Links) — logs the payment against the matching client
// in Supabase and drops a note in the activity feed (which lights up the
// notification bell and Dashboard automatically).
//
// Secrets to set (Supabase Dashboard -> Edge Functions -> stripe-webhook ->
// Secrets — NOT in this file, and NOT pasted into chat):
//   STRIPE_SECRET_KEY     your Stripe secret key, sk_live_... (or sk_test_...)
//   STRIPE_WEBHOOK_SECRET the signing secret Stripe shows you after you
//                         create the webhook endpoint, whsec_...
//
// SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY are injected automatically by
// Supabase for every Edge Function — you do not set those yourself.
// ---------------------------------------------------------------------------

import Stripe from "npm:stripe@16";
import { createClient } from "npm:@supabase/supabase-js@2";

const stripe = new Stripe(Deno.env.get("STRIPE_SECRET_KEY") ?? "", {
  apiVersion: "2024-06-20",
});
const webhookSecret = Deno.env.get("STRIPE_WEBHOOK_SECRET") ?? "";

const supabase = createClient(
  Deno.env.get("SUPABASE_URL") ?? "",
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "",
);

Deno.serve(async (req) => {
  const signature = req.headers.get("stripe-signature");
  const body = await req.text(); // raw body — required for signature check

  if (!signature) return new Response("Missing signature", { status: 400 });

  let event: Stripe.Event;
  try {
    event = await stripe.webhooks.constructEventAsync(body, signature, webhookSecret);
  } catch (err) {
    console.error("Signature verification failed:", err);
    return new Response("Invalid signature", { status: 400 });
  }

  if (event.type === "checkout.session.completed") {
    const session = event.data.object as Stripe.Checkout.Session;
    const clientId = session.client_reference_id;
    const amount = (session.amount_total ?? 0) / 100;

    if (clientId) {
      const { data: client } = await supabase
        .from("clients")
        .select("business")
        .eq("id", clientId)
        .maybeSingle();

      // unique index on stripe_session_id means a retried Stripe delivery
      // never double-logs the same payment
      const { error } = await supabase.from("payments").insert({
        client_id: clientId,
        amount,
        kind: "Stripe payment",
        note: "Paid online via Stripe",
        stripe_session_id: session.id,
      });

      if (error && !String(error.message).includes("duplicate key")) {
        console.error("Insert payment failed:", error);
      } else if (!error) {
        await supabase.from("activity").insert({
          client_id: clientId,
          type: "payment",
          title: (client?.business || "A client") + " paid $" + amount.toFixed(2) + " via Stripe",
        });
      }
    } else {
      console.warn("checkout.session.completed with no client_reference_id — skipped");
    }
  }

  return new Response(JSON.stringify({ received: true }), {
    headers: { "Content-Type": "application/json" },
  });
});
