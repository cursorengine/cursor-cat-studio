-- ============================================================================
-- Cursor Cat Studio — Supabase setup (idempotent; safe to re-run)
-- Run this in: Supabase Dashboard -> SQL Editor -> New query -> Run
-- ============================================================================

create extension if not exists pgcrypto;

-- ---------------------------------------------------------------------------
-- clients: one row per client. Single source of truth for every document.
-- ---------------------------------------------------------------------------
create table if not exists public.clients (
  id            uuid primary key default gen_random_uuid(),
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),

  -- who
  business      text not null default '',
  contact_name  text default '',
  city          text default '',
  email         text default '',
  phone         text default '',
  offer         text default 'Local Lead Engine',
  stage         text default 'Prospect',

  -- intake / context
  website       text default '',
  gbp_url       text default '',
  service_areas text default '',
  top_services  text default '',
  avg_job_value text default '',
  target_jobs   text default '',
  competitor    text default '',
  notes         text default '',
  goal          text default '',
  start_week    text default '',

  -- document meta
  proposal_num  text default '',
  agreement_num text default '',
  invoice_num   text default '',
  packet_num    text default '',
  doc_date      text default '',

  -- money
  subtotal      text default '',
  tax_label     text default 'GST (5%)',
  tax           text default '',
  total         text default '',
  deposit       text default '',
  balance       text default '',
  weeks         text default '6',

  -- repeatable blocks (stored as raw text, parsed by the app)
  --   gaps_raw         : one gap per line
  --   deliverables_raw : "Title | Description" per line
  --   timeline_raw     : "Week | Description" per line
  --   line_items_raw   : "Label | Value" per line
  --   scope_raw        : one scope item per line
  gaps_raw         text default '',
  deliverables_raw text default '',
  timeline_raw     text default '',
  line_items_raw   text default '',
  scope_raw        text default ''
);

-- ---------------------------------------------------------------------------
-- Upgrade safety: add any column that might be missing on an existing table.
-- ---------------------------------------------------------------------------
alter table public.clients add column if not exists created_at    timestamptz not null default now();
alter table public.clients add column if not exists updated_at    timestamptz not null default now();
alter table public.clients add column if not exists business      text not null default '';
alter table public.clients add column if not exists contact_name  text default '';
alter table public.clients add column if not exists city          text default '';
alter table public.clients add column if not exists email         text default '';
alter table public.clients add column if not exists phone         text default '';
alter table public.clients add column if not exists offer         text default 'Local Lead Engine';
alter table public.clients add column if not exists stage         text default 'Prospect';
alter table public.clients add column if not exists website       text default '';
alter table public.clients add column if not exists gbp_url       text default '';
alter table public.clients add column if not exists service_areas text default '';
alter table public.clients add column if not exists top_services  text default '';
alter table public.clients add column if not exists avg_job_value text default '';
alter table public.clients add column if not exists target_jobs   text default '';
alter table public.clients add column if not exists competitor    text default '';
alter table public.clients add column if not exists notes         text default '';
alter table public.clients add column if not exists goal          text default '';
alter table public.clients add column if not exists start_week    text default '';
alter table public.clients add column if not exists proposal_num  text default '';
alter table public.clients add column if not exists agreement_num text default '';
alter table public.clients add column if not exists invoice_num   text default '';
alter table public.clients add column if not exists packet_num    text default '';
alter table public.clients add column if not exists doc_date      text default '';
alter table public.clients add column if not exists subtotal      text default '';
alter table public.clients add column if not exists tax_label     text default 'GST (5%)';
alter table public.clients add column if not exists tax           text default '';
alter table public.clients add column if not exists total         text default '';
alter table public.clients add column if not exists deposit       text default '';
alter table public.clients add column if not exists balance       text default '';
alter table public.clients add column if not exists weeks         text default '6';
alter table public.clients add column if not exists gaps_raw         text default '';
alter table public.clients add column if not exists deliverables_raw text default '';
alter table public.clients add column if not exists timeline_raw     text default '';
alter table public.clients add column if not exists line_items_raw   text default '';
alter table public.clients add column if not exists scope_raw        text default '';

-- ---------------------------------------------------------------------------
-- keep updated_at fresh on every update
-- ---------------------------------------------------------------------------
create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists trg_clients_updated on public.clients;
create trigger trg_clients_updated
  before update on public.clients
  for each row execute function public.set_updated_at();

-- ---------------------------------------------------------------------------
-- Row Level Security: signed-in users only. The public anon key cannot read
-- or write client data (it's PII), so this is safe to host on GitHub Pages.
-- ---------------------------------------------------------------------------
alter table public.clients enable row level security;

drop policy if exists clients_authenticated_all on public.clients;
create policy clients_authenticated_all
  on public.clients
  for all
  to authenticated
  using (true)
  with check (true);

-- helpful index for the pipeline view
create index if not exists clients_stage_idx on public.clients (stage);
create index if not exists clients_created_idx on public.clients (created_at desc);

-- ============================================================================
-- v2 — client portal, self-serve intake, e-signatures, payments
-- (additive + idempotent; safe to re-run over v1)
-- ============================================================================

alter table public.clients add column if not exists portal_token      text;
alter table public.clients add column if not exists intake_submitted  boolean default false;
alter table public.clients add column if not exists signed_proposal   jsonb;
alter table public.clients add column if not exists signed_agreement  jsonb;
create unique index if not exists clients_portal_token_idx
  on public.clients (portal_token) where portal_token is not null;

-- payments / revenue
create table if not exists public.payments (
  id         uuid primary key default gen_random_uuid(),
  client_id  uuid references public.clients(id) on delete cascade,
  created_at timestamptz not null default now(),
  paid_on    date default current_date,
  amount     numeric(12,2) not null default 0,
  kind       text default 'Deposit',
  note       text default ''
);
alter table public.payments enable row level security;
drop policy if exists payments_authenticated_all on public.payments;
create policy payments_authenticated_all on public.payments
  for all to authenticated using (true) with check (true);
create index if not exists payments_client_idx on public.payments (client_id);

-- ---------- public, token-gated RPCs (SECURITY DEFINER) ----------
-- The anon key in the page source can ONLY call these three functions; it has
-- no direct table access. Each verifies the per-client secret token server-side.

create or replace function public.get_portal(p_token text)
returns jsonb language plpgsql security definer set search_path = public as $$
declare r public.clients%rowtype;
begin
  select * into r from public.clients where portal_token = p_token;
  if not found then return null; end if;
  return jsonb_build_object(
    'business',r.business,'contact_name',r.contact_name,'city',r.city,'offer',r.offer,
    'stage',r.stage,'goal',r.goal,'start_week',r.start_week,'doc_date',r.doc_date,
    'intake_submitted',r.intake_submitted,
    'signed_proposal',(r.signed_proposal is not null),
    'signed_agreement',(r.signed_agreement is not null),
    'proposal_num',r.proposal_num,'agreement_num',r.agreement_num,
    'total',r.total,'deposit',r.deposit,'balance',r.balance,'weeks',r.weeks,
    'subtotal',r.subtotal,'tax_label',r.tax_label,'tax',r.tax,
    'gaps_raw',r.gaps_raw,'deliverables_raw',r.deliverables_raw,'timeline_raw',r.timeline_raw,
    'line_items_raw',r.line_items_raw,'scope_raw',r.scope_raw
  );
end $$;

create or replace function public.submit_intake(p_token text, p_data jsonb)
returns boolean language plpgsql security definer set search_path = public as $$
declare cid uuid;
begin
  select id into cid from public.clients where portal_token = p_token;
  if cid is null then return false; end if;
  update public.clients set
    contact_name  = coalesce(nullif(p_data->>'contact_name',''), contact_name),
    phone         = coalesce(nullif(p_data->>'phone',''), phone),
    email         = coalesce(nullif(p_data->>'email',''), email),
    website       = coalesce(p_data->>'website', website),
    gbp_url       = coalesce(p_data->>'gbp_url', gbp_url),
    service_areas = coalesce(p_data->>'service_areas', service_areas),
    top_services  = coalesce(p_data->>'top_services', top_services),
    avg_job_value = coalesce(p_data->>'avg_job_value', avg_job_value),
    target_jobs   = coalesce(p_data->>'target_jobs', target_jobs),
    competitor    = coalesce(p_data->>'competitor', competitor),
    notes         = coalesce(p_data->>'notes', notes),
    intake_submitted = true
  where id = cid;
  return true;
end $$;

create or replace function public.submit_signature(p_token text, p_doc text, p_name text, p_sig text)
returns boolean language plpgsql security definer set search_path = public as $$
declare cid uuid; sig jsonb;
begin
  select id into cid from public.clients where portal_token = p_token;
  if cid is null then return false; end if;
  sig := jsonb_build_object('name', p_name, 'image', p_sig, 'signed_at', now());
  if p_doc = 'proposal' then
    update public.clients set signed_proposal = sig where id = cid;
  elsif p_doc = 'agreement' then
    update public.clients set signed_agreement = sig where id = cid;
  else
    return false;
  end if;
  return true;
end $$;

revoke all on function public.get_portal(text)                     from public;
revoke all on function public.submit_intake(text,jsonb)            from public;
revoke all on function public.submit_signature(text,text,text,text) from public;
grant execute on function public.get_portal(text)                     to anon, authenticated;
grant execute on function public.submit_intake(text,jsonb)            to anon, authenticated;
grant execute on function public.submit_signature(text,text,text,text) to anon, authenticated;
