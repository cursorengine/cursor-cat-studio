# Cursor Cat Studio

A single-file web app to manage clients and auto-generate every onboarding document
(Proposal, Service Agreement, Welcome Packet, Intake Form, Invoice) — all branded to
cursorcat.digital, all filled from one place, all exportable to PDF in one click.

Backed by **Supabase**. Hosts as a **static site** (GitHub Pages). No build step.

---

## What's in this folder

| File | Purpose |
|------|---------|
| `index.html` | The whole app (vanilla JS, no framework). |
| `supabase_setup.sql` | Database schema + security. Run once in Supabase. |
| `cat-icon.png` | App + document logo. |
| `README.md` | This file. |

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
