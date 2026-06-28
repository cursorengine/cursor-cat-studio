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
| `config.js` | Your Supabase URL + anon key (used by the client-facing pages). |
| `brand.css` | Shared styling for the client-facing pages. |
| `docs.js` | Shared document rendering for the signing page. |
| `supabase_setup.sql` | Database schema + security. Run once in Supabase. |
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
