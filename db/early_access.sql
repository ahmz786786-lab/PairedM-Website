-- ============================================================
-- PairedM — Early Access / Launch Waitlist
-- Backs landing.html (the social-media pre-launch landing page).
--
-- Run once in the PairedM Supabase project (marjtiotfdvlbnnuvfjg)
-- via the SQL Editor, or the Management API:
--   POST /v1/projects/marjtiotfdvlbnnuvfjg/database/query
--
-- Safe to re-run (idempotent).
-- ============================================================

create extension if not exists pgcrypto;

-- ---------- Table ----------
create table if not exists public.early_access_signups (
  id            uuid primary key default gen_random_uuid(),
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),
  email         text not null,
  gender        text check (gender in ('male','female')),
  city          text,
  wants_updates boolean not null default true,
  source        text not null default 'landing',   -- e.g. landing / instagram / tiktok (?utm_source)
  unsubscribed  boolean not null default false
);

-- ---------- v2 columns (2026-08-08): marriage timeline + age ----------
-- Added separately so this file stays re-runnable against the v1 table.
alter table public.early_access_signups
  add column if not exists timeline text,
  add column if not exists age      int;

do $$ begin
  alter table public.early_access_signups
    add constraint early_access_timeline_chk
    check (timeline is null or timeline in ('asap','6_months','12_months','exploring'));
exception when duplicate_object then null; end $$;

do $$ begin
  alter table public.early_access_signups
    add constraint early_access_age_chk
    check (age is null or age between 18 and 99);
exception when duplicate_object then null; end $$;

-- One row per person. Re-submitting the same email updates the existing row.
create unique index if not exists uq_early_access_email
  on public.early_access_signups (lower(email));
create index if not exists idx_early_access_created
  on public.early_access_signups (created_at desc);

-- Lock down direct access; only the SECURITY DEFINER RPCs below may touch rows.
alter table public.early_access_signups enable row level security;
revoke all on public.early_access_signups from anon, authenticated;

-- ---------- Sign up ----------
-- Idempotent on email: re-submitting updates the other fields rather than
-- erroring, so the form can always show a friendly success state.
--
-- The v1 five-argument signature is dropped rather than left in place: two
-- overloads differing only by defaults make PostgREST unable to resolve a call.
drop function if exists public.early_access_signup(text,text,text,boolean,text);

create or replace function public.early_access_signup(
  p_email         text,
  p_gender        text default null,
  p_city          text default null,
  p_wants_updates boolean default true,
  p_source        text default 'landing',
  p_timeline      text default null,
  p_age           int  default null
) returns json
language plpgsql security definer set search_path = public as $$
declare
  v_email    text := nullif(lower(trim(p_email)), '');
  v_gender   text := nullif(lower(trim(p_gender)), '');
  v_city     text := nullif(trim(p_city), '');
  v_source   text := coalesce(nullif(trim(p_source), ''), 'landing');
  v_timeline text := nullif(lower(trim(p_timeline)), '');
  v_age      int  := p_age;
  v_new      boolean;
  v_id       uuid;
begin
  if v_email is null or v_email !~ '^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$' then
    return json_build_object('ok', false, 'error', 'INVALID_EMAIL');
  end if;

  -- Everything past the email is coerced, never rejected: an out-of-range age
  -- or an unknown timeline slug must not cost us the signup. The form does the
  -- friendly validation up front; this is the backstop.
  if v_gender is not null and v_gender not in ('male','female') then
    v_gender := null;
  end if;

  if v_timeline is not null and v_timeline not in ('asap','6_months','12_months','exploring') then
    v_timeline := null;
  end if;

  if v_age is not null and (v_age < 18 or v_age > 99) then
    v_age := null;
  end if;

  v_city   := left(v_city, 80);
  v_source := left(v_source, 40);

  select id into v_id
    from public.early_access_signups
   where lower(email) = v_email;
  v_new := v_id is null;

  insert into public.early_access_signups
    (email, gender, city, wants_updates, source, timeline, age)
  values
    (v_email, v_gender, v_city, coalesce(p_wants_updates, true), v_source, v_timeline, v_age)
  on conflict (lower(email)) do update
    set gender        = coalesce(excluded.gender,   early_access_signups.gender),
        city          = coalesce(excluded.city,     early_access_signups.city),
        timeline      = coalesce(excluded.timeline, early_access_signups.timeline),
        age           = coalesce(excluded.age,      early_access_signups.age),
        wants_updates = excluded.wants_updates,
        unsubscribed  = false,
        updated_at    = now()
  returning id into v_id;

  return json_build_object('ok', true, 'id', v_id, 'already_signed_up', not v_new);
end $$;

-- ---------- Unsubscribe (for the footer of update emails) ----------
create or replace function public.early_access_unsubscribe(p_email text)
returns json
language plpgsql security definer set search_path = public as $$
declare v_email text := nullif(lower(trim(p_email)), '');
begin
  update public.early_access_signups
     set unsubscribed = true, wants_updates = false, updated_at = now()
   where lower(email) = v_email;
  return json_build_object('ok', found);
end $$;

-- ---------- Public safe aggregate ----------
-- Used by the landing page's social-proof counter. The page only renders the
-- number once it passes its own threshold, so an early low count never shows.
create or replace function public.early_access_count()
returns json
language sql security definer set search_path = public as $$
  select json_build_object('total', count(*)) from public.early_access_signups;
$$;

-- ---------- Admin list (secret-gated) ----------
-- This repo is PUBLIC and GitHub Pages serves it, so the real secret must
-- never be committed here. Substitute it at deploy time. Left unsubstituted,
-- the function refuses every call rather than shipping a publicly known secret.
create or replace function public.early_access_admin_list(p_secret text)
returns setof public.early_access_signups
language plpgsql security definer set search_path = public as $$
declare
  v_expected text := '__ADMIN_SECRET__';
begin
  if v_expected = '__ADMIN' || '_SECRET__' then
    raise exception 'ADMIN_SECRET_NOT_SET — substitute the real secret before running this file';
  end if;
  if p_secret is null or p_secret <> v_expected then
    raise exception 'UNAUTHORIZED';
  end if;
  return query
    select * from public.early_access_signups order by created_at desc;
end $$;

-- ---------- Grants ----------
grant execute on function public.early_access_signup(text,text,text,boolean,text,text,int) to anon, authenticated;
grant execute on function public.early_access_unsubscribe(text)                   to anon, authenticated;
grant execute on function public.early_access_count()                             to anon, authenticated;
grant execute on function public.early_access_admin_list(text)                    to anon, authenticated;
