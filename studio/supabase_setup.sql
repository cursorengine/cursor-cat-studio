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
