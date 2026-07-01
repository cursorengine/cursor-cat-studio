# Cursor Cat Studio

A single-file web app to manage clients and auto-generate every onboarding document
(Proposal, Service Agreement, Welcome Packet, Intake Form, Invoice) — all branded to
cursorcat.digital, all filled from one place, all exportable to PDF in one click.

Backed by **Supabase**. Hosts as a **static site** (GitHub Pages). No build step.

---

## What's in this folder

| File | Purpose |
|------|---------|
| `index.html` | The admin app — manage clients, generate docs, payments, dashboard (vanilla JS). |
| `portal.html` | Client-facing portal — live progress tracker + links (one per client). |
| `intake.html` | Client-facing self-serve intake form. |
| `sign.html` | Client-facing e-signature page for proposal / agreement. |
| `invoice.html` | Client-facing invoice view — line items, totals, e-transfer info, Pay button. |
| `config.js` | Your Supabase URL + anon key (used by the client-facing pages). |
| `brand.css` | Shared styling for the client-facing pages. |
| `docs.js` | Shared document rendering for the signing page. |
| `supabase_setup.sql` | Database schema + security. Run once in Supabase. |
| `stripe-webhook.ts` | Supabase Edge Function — auto-logs Stripe payments (see v7 below). |
| `crestcatccdlogo.png`, `navbar-logo.png` | Logos (icon + wordmark). |
| `README.md` | This file. |

**Upload ALL of these to your repo** (same root level) so the app and the client pages work.

---

## One-time setup (about 10 minutes)

### 1. Create a Supabase project
Go to [supabase.com](https://supabase.com) → **New project**. Pick a name and a strong
database password. Wait ~2 min for it to provision.

### 2. Create the database table
In Supabase: **SQL Editor → New query** → paste the entire contents of
`supabase_setup.sql` → **Run**. You should see "Success."

### 3. Create your login
The app is private (only signed-in users can see client data). Create your user:
**Authentication → Users → Add user → Create new user.** Enter your email + a password,
and tick **Auto Confirm User** so you can log in right away.

### 4. Get your API keys
**Project Settings → API.** Copy:
- **Project URL** (e.g. `https://abcd1234.supabase.co`)
- **anon / public key** (the long `eyJ...` string — this one is safe to use in a
  public site; the table is locked to signed-in users by Row Level Security.)

### 5. Open the app and connect
Open `index.html` (locally or once deployed). On the login screen click
**Connection settings**, paste the URL and anon key, **Save & reload**. Then sign in
with the email/password from step 3.

> Keys are stored in your browser only (localStorage), not in the code — so nothing
> secret is committed to GitHub.

---

## Deploy to GitHub Pages

1. Create a new repo (e.g. `cursor-cat-studio`) and push this `studio/` folder's contents
   to it (so `index.html` is at the repo root, or in `/docs`).
2. Repo **Settings → Pages →** Source: `main` branch, root (or `/docs`).
3. Your app will be live at `https://<you>.github.io/cursor-cat-studio/`.
4. Open it, enter your connection settings once, and sign in.

---

## How to use it day to day

- **+ New Client** → fill the **Details** tab → **Save**. That client now drives every document.
- Switch tabs (**Proposal / Agreement / Welcome / Intake / Invoice**) to see each document
  auto-filled and on-brand.
- **↓ Export PDF** on any document tab to download a clean PDF.
- Use the **stage dropdown** (top right) to move a client through onboarding:
  Prospect → Proposal Sent → Signed → Deposit Paid → Intake → Kick-off → Active → Closed.
  The sidebar shows a live pipeline count.

### The repeatable fields (Details tab)
Some fields take one item per line so they flow into the documents:

- **Gaps** — one per line → proposal "what's holding you back" list.
- **Deliverables** — `Title | Description` per line → proposal "what's included".
- **Timeline** — `Week | Description` per line → proposal timeline.
- **Line items** — `Label | Value` per line → proposal investment table **and** the invoice.
- **Scope** — one per line → service agreement scope.

Edit the numbers once (total, deposit, balance, tax) and they update across the proposal,
agreement, and invoice together.

---

## Notes
- Data lives in Supabase, so it's the same on every device you sign in from.
- The anon key is meant to be public; security comes from RLS (`authenticated` only).
  Re-run `supabase_setup.sql` any time — it's idempotent.
- Built to match cursorcat.digital: light theme, chrome accents, custom cursor,
  Space Grotesk / Inter / JetBrains Mono.

---

## v2 — client portal, self-serve intake, e-signing, payments, dashboard

### Extra one-time setup
1. **Re-run `supabase_setup.sql`** in the Supabase SQL Editor. It's idempotent —
   safe to run again — and adds the payments table, the e-sign/portal columns, and
   the secure public functions the client pages use.
2. **Fill in `config.js`** with the same Supabase URL + anon key, then upload it.
   The client-facing pages (portal / intake / sign) read their connection from here.
   It's safe to commit: the anon key is public and every public action is gated by a
   secret per-client token plus Row Level Security.

### How the client-facing flow works
Each client gets a private link (no login for them). In the app, open a saved client
and use the **⧉ Portal / Intake / Sign** buttons (top bar or Details tab) to copy a link:

- **Portal** (`portal.html?t=…`) — a branded page showing their live onboarding
  progress, checklist, and buttons to sign and complete intake. Confetti when done.
- **Intake** (`intake.html?t=…`) — they fill it themselves; answers save straight
  into their record (no retyping for you).
- **Sign** (`sign.html?doc=proposal…` / `…doc=agreement…`) — they review the document
  and sign on screen (type + draw). Status flips to signed, with a timestamp, and the
  signature shows on the document in the app.

The secret token is created the first time you copy a link for that client.

### New in the app
- **Dashboard** — the home screen (when no client is selected): client count, open
  pipeline value, all-time collected, active clients, and a "needs attention" list.
- **Offer presets** — on the Details tab, pick an offer and click **⚡ Load preset**
  to auto-fill pricing, line items, deliverables, timeline, and scope.
- **Payments tab** — log deposits/balances/retainers per client; see collected vs.
  outstanding. Feeds the dashboard's all-time revenue.
- **E-sign status** — signed proposals/agreements show the client's signature and date.

### Files to upload for v2
`config.js`, `brand.css`, `docs.js`, `portal.html`, `intake.html`, `sign.html`
(plus the updated `index.html` and both logo PNGs).

---

## v3 — automations, notifications, file uploads, activity

### One-time setup
**Re-run `supabase_setup.sql`** again (still idempotent). v3 adds: the `activity`
table, real-time on `activity`/`payments`, a `client-uploads` storage bucket, file
support on clients, and upgraded functions (auto-advance, activity logging, view
tracking). Then re-upload the updated `index.html`, `intake.html`, `portal.html`,
and `sign.html`.

### What's new
- **Auto counter-signature** — the instant a client signs, your signature + date are
  stamped automatically; the document shows both signatures as fully executed.
- **Auto-advance to "Signed"** — once both proposal and agreement are signed, the
  client's stage moves to Signed on its own.
- **Auto-log payments on stage change** — move a client to *Deposit Paid* and the
  deposit logs itself; *Active* or *Closed* logs the balance. Pulled from the contract
  numbers, never double-logged.
- **Dashboard tab** — a Dashboard button in the top bar opens the overview any time.
- **Real-time notification bell** — lights up live (no refresh) when a client signs,
  completes intake, views their portal, or pays. Click it to see the feed; opening it
  marks items read. The Dashboard also shows a Recent Activity list.
- **Auto-reminders** — clients who haven't signed/done intake within 2 days surface in
  the bell and on the Dashboard.
- **Client file uploads** — clients can attach their logo + job photos in the intake
  form; files land in Supabase storage and on the client record.
- **"Viewed" tracking** — you get notified when a client opens their portal or a doc.
- **Revenue CSV export** — the Dashboard has a "Revenue CSV" button.

### Re-upload for v3
The updated `index.html`, `intake.html`, `portal.html`, `sign.html` — and re-run the SQL.

---

## v4 — delivery tracking + high-tech dashboard

### One-time setup
**Re-run `supabase_setup.sql`** (adds the `tasks` table + realtime). Re-upload `index.html`.

### What's new
- **Project tab** (per client) — plan and track the work by phase. Click **Load the
  4-phase plan** to drop in the standard Foundation → GBP/SEO → Ads → Handoff checklist,
  or add your own tasks. A progress bar shows how far along the build is.
- **Dashboard charts** — the Dashboard now shows **Revenue by month** and **Pipeline by
  stage** charts (Chart.js), on top of the metric cards, reminders, and activity feed.

### Re-upload for v4
The updated `index.html` — and re-run the SQL.

---

## Roadmap — features that need a backend (Supabase Edge Functions) + accounts

These need a small server-side function and your own account/API key. When you're
ready, set up the account and I'll build the function + wire it into the app:

- **One-click email send** — an email provider (e.g. Resend) API key. Sends the portal /
  proposal / invoice link from inside the app. (Lite version now: a "Send" button that
  opens your email client pre-filled.)
- **AI proposal & audit drafting** — an AI provider API key. Paste a website or call notes
  and it drafts the gaps, deliverables, and suggested pricing into the client record.

Also queued: client-facing project progress in the portal, recurring retainer billing.

---

## v5 — lite versions (no accounts) + mobile

### One-time setup
**Re-run `supabase_setup.sql`** (adds a `pay_link` column + updates the portal function).
Re-upload `index.html` and `portal.html`.

### What's new — all no-account
- **Lite payments** — on a client's Details tab there's a **Payment link** field. Paste a
  Stripe Payment Link (you can create those free in Stripe with no code) and a **Pay**
  button appears on the invoice and on the client's portal. When they pay and you move the
  stage to Deposit Paid, it still auto-logs the payment.
- **Lite email send** — **✉ Email portal** / **✉ Email proposal** buttons on the Details
  tab open your email app with the client's address, a subject, and the link pre-filled.
  One click to send from your own inbox.
- **AI brief prompt** — **✨ Copy AI brief prompt** copies a ready-made prompt built from
  the client's info. Paste it into Claude or ChatGPT, then paste the answer back into the
  Gaps / Deliverables / Timeline boxes. (Full in-app AI still needs an API key later.)
- **Mobile** — the top bar now has a menu button that slides the client list in/out, the
  logo taps back to the Dashboard, and the dashboard / payments / project grids reflow to
  fit small screens.

### Re-upload for v5
`index.html`, `portal.html` — and re-run the SQL.

---

## v6 — Kanban, command palette, MRR + reporting

### One-time setup
**Re-run `supabase_setup.sql`** (adds a `monthly` column). Re-upload `index.html`.

### What's new
- **Pipeline Kanban board** — a **Board** button in the top bar opens a drag-and-drop
  board. Drag a client between stage columns to move them — and dragging fires the same
  auto-payment-logging (drop into Deposit Paid → logs the deposit).
- **Command palette** — press **Ctrl/Cmd + K** anywhere to jump to any client or action
  (Dashboard, Board, New client). Type to filter, Enter to go.
- **MRR + reporting on the Dashboard** — new metric cards for **MRR** (from each client's
  Monthly retainer field), **Avg deal**, and **Win rate**, plus a **Conversion funnel**
  chart (Leads → Proposal → Signed → Deposit → Active).
- **Monthly retainers** — set a client's **Monthly retainer** on Details, then click
  **↻ Log retainers** on the Dashboard to record this month's retainer payments for active
  retainer clients (skips any already logged this month).
- **Cleanup** — removed dead code left from earlier refactors; tightened the build.

### Re-upload for v6
`index.html` — and re-run the SQL.

---

## v7 — Stripe webhook automation (payments auto-log, no manual step)

Builds on the v5 "lite payments" Payment Link — you still paste one Stripe Payment Link
per client. The difference: when a client actually pays, Stripe now tells Supabase
directly, so the payment logs itself (Payments tab, Dashboard revenue, notification bell)
instead of you having to remember to flip the stage or type it in.

### One-time setup
1. **Re-run `supabase_setup.sql`** (adds `stripe_session_id` to `payments` for
   dedupe, and adds the client's `id` to the portal RPC output).
2. **Deploy the webhook function** — Supabase Dashboard → Edge Functions → Create a
   function → name it `stripe-webhook` → paste the contents of `stripe-webhook.ts` →
   Deploy.
3. **Set function secrets** (Edge Functions → stripe-webhook → Secrets — never in code
   or chat): `STRIPE_SECRET_KEY` (your sk_live_… key) and, once you've created the
   webhook endpoint below, `STRIPE_WEBHOOK_SECRET` (the whsec_… signing secret).
4. **Create the Stripe webhook** — Stripe Dashboard → Developers → Webhooks → Add
   endpoint → URL is your function's URL (shown after deploy, looks like
   `https://<project-ref>.supabase.co/functions/v1/stripe-webhook`) → listen for
   `checkout.session.completed` → copy the signing secret into step 3.
5. **Re-upload** `index.html` and `portal.html` (the Pay buttons now tag the Stripe
   link with the client's ID so the webhook knows who paid).

### Re-upload for v7
`index.html`, `portal.html`, `supabase_setup.sql` (run it), plus deploy `stripe-webhook.ts`
as an Edge Function.

---

## v8 — invoice view on the client portal

Before v8, a client's portal had a bare "Pay" button with no way to see what they were
actually paying for. Now there's a real invoice page — same line items, subtotal, tax,
and total as the Invoice tab in the app, plus the e-transfer instructions and the Pay
button.

### One-time setup
**Re-run `supabase_setup.sql`** (adds `invoice_num` and `email` to the portal RPC).
Re-upload `portal.html` and upload the new `invoice.html`.

### What's new
- **`invoice.html?t=…`** — a client-facing invoice page (token-gated, same pattern as
  portal/intake/sign). Shows Bill To, line items, subtotal/tax/total, how to pay
  (e-Transfer + the Pay button), and the payment schedule note.
- **"View your invoice" link on the portal** — appears above the Pay button whenever a
  client has a total set, so they can see the breakdown before paying, or just to check
  what they owe without emailing you.

### Re-upload for v8
`portal.html`, `invoice.html` — and re-run the SQL.
