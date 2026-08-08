-- ============================================================
-- PairedM Launch Event — Registration System
-- Event: Halal Matrimonial Service Launch — Sat 27 June 2026, 9:45-10:45pm
-- Capacity: 60 male + 60 female (confirmed). Overflow -> waiting list.
-- Cancelling a confirmed seat auto-promotes the next same-gender
-- person from the waiting list.
--
-- Run this once in the PairedM Supabase project (SQL Editor or psql).
-- Safe to re-run (idempotent).
-- ============================================================

create extension if not exists pgcrypto;

-- ---------- Table ----------
create table if not exists public.event_registrations (
  id              uuid primary key default gen_random_uuid(),
  created_at      timestamptz not null default now(),
  event_id        text not null default 'launch_2026_06_27',
  full_name       text not null,
  email           text,
  phone           text,
  gender          text not null check (gender in ('male','female')),
  can_attend      boolean not null default true,   -- Q2
  interested_app  boolean not null default false,  -- Q3
  status          text not null default 'waitlist'
                    check (status in ('confirmed','waitlist','cancelled')),
  cancel_token    uuid not null default gen_random_uuid(),
  promoted_at     timestamptz
);

create index if not exists idx_event_reg_lookup
  on public.event_registrations (event_id, gender, status, created_at);
create unique index if not exists uq_event_reg_token
  on public.event_registrations (cancel_token);

-- Lock down direct access; only the SECURITY DEFINER RPCs below may touch rows.
alter table public.event_registrations enable row level security;
revoke all on public.event_registrations from anon, authenticated;

-- ---------- Capacity (per gender) ----------
create or replace function public.event_capacity() returns int
  language sql immutable as $$ select 60 $$;

-- ---------- Register ----------
create or replace function public.event_register(
  p_name text,
  p_email text,
  p_phone text,
  p_gender text,
  p_can_attend boolean,
  p_interested_app boolean,
  p_event_id text default 'launch_2026_06_27'
) returns json
language plpgsql security definer set search_path = public as $$
declare
  v_gender   text := lower(trim(p_gender));
  v_email    text := nullif(lower(trim(p_email)), '');
  v_phone    text := nullif(trim(p_phone), '');
  v_name     text := nullif(trim(p_name), '');
  v_cap      int  := public.event_capacity();
  v_confirmed int;
  v_status   text;
  v_row      public.event_registrations%rowtype;
  v_existing public.event_registrations%rowtype;
  v_wl_pos   int;
begin
  if v_name is null then raise exception 'NAME_REQUIRED'; end if;
  if v_gender not in ('male','female') then raise exception 'GENDER_INVALID'; end if;
  if v_email is null or v_phone is null then raise exception 'CONTACT_REQUIRED'; end if;

  -- Serialise registrations per (event, gender) so the 60-cap is race-safe.
  perform pg_advisory_xact_lock(hashtext(p_event_id || ':' || v_gender));

  -- Idempotency: if this email/phone already has an active registration, return it.
  select * into v_existing
    from public.event_registrations
   where event_id = p_event_id
     and status <> 'cancelled'
     and ( (v_email is not null and lower(email) = v_email)
        or (v_phone is not null and phone = v_phone) )
   order by created_at asc
   limit 1;

  if found then
    if v_existing.status = 'waitlist' then
      select count(*) into v_wl_pos from public.event_registrations
       where event_id = p_event_id and gender = v_existing.gender
         and status = 'waitlist' and created_at <= v_existing.created_at;
    end if;
    return json_build_object(
      'status', v_existing.status,
      'gender', v_existing.gender,
      'cancel_token', v_existing.cancel_token,
      'already_registered', true,
      'waitlist_position', v_wl_pos
    );
  end if;

  select count(*) into v_confirmed from public.event_registrations
   where event_id = p_event_id and gender = v_gender and status = 'confirmed';

  if v_confirmed < v_cap then v_status := 'confirmed'; else v_status := 'waitlist'; end if;

  insert into public.event_registrations
    (event_id, full_name, email, phone, gender, can_attend, interested_app, status)
  values
    (p_event_id, v_name, v_email, v_phone, v_gender,
     coalesce(p_can_attend, true), coalesce(p_interested_app, false), v_status)
  returning * into v_row;

  if v_status = 'waitlist' then
    select count(*) into v_wl_pos from public.event_registrations
     where event_id = p_event_id and gender = v_gender
       and status = 'waitlist' and created_at <= v_row.created_at;
  end if;

  return json_build_object(
    'status', v_status,
    'gender', v_gender,
    'cancel_token', v_row.cancel_token,
    'already_registered', false,
    'waitlist_position', v_wl_pos,
    'remaining', greatest(v_cap - (v_confirmed + (case when v_status='confirmed' then 1 else 0 end)), 0)
  );
end $$;

-- ---------- Cancel (auto-promotes next on the waiting list) ----------
create or replace function public.event_cancel(p_cancel_token uuid)
returns json language plpgsql security definer set search_path = public as $$
declare
  v_row      public.event_registrations%rowtype;
  v_promoted public.event_registrations%rowtype;
begin
  select * into v_row from public.event_registrations where cancel_token = p_cancel_token;
  if not found then raise exception 'NOT_FOUND'; end if;
  if v_row.status = 'cancelled' then
    return json_build_object('ok', true, 'already_cancelled', true);
  end if;

  perform pg_advisory_xact_lock(hashtext(v_row.event_id || ':' || v_row.gender));

  update public.event_registrations set status = 'cancelled' where id = v_row.id;

  if v_row.status = 'confirmed' then
    select * into v_promoted from public.event_registrations
     where event_id = v_row.event_id and gender = v_row.gender and status = 'waitlist'
     order by created_at asc limit 1;
    if found then
      update public.event_registrations
         set status = 'confirmed', promoted_at = now()
       where id = v_promoted.id;
    end if;
  end if;

  return json_build_object(
    'ok', true,
    'was_status', v_row.status,
    'name', v_row.full_name,
    'promoted', case when v_promoted.id is not null then
      json_build_object('full_name', v_promoted.full_name, 'email', v_promoted.email,
                        'phone', v_promoted.phone, 'gender', v_promoted.gender)
      else null end
  );
end $$;

-- ---------- Public availability (safe aggregate, no PII) ----------
create or replace function public.event_availability(p_event_id text default 'launch_2026_06_27')
returns json language sql security definer set search_path = public as $$
  select json_build_object(
    'capacity',         public.event_capacity(),
    'male_confirmed',   count(*) filter (where gender='male'   and status='confirmed'),
    'female_confirmed', count(*) filter (where gender='female' and status='confirmed'),
    'male_waitlist',    count(*) filter (where gender='male'   and status='waitlist'),
    'female_waitlist',  count(*) filter (where gender='female' and status='waitlist'),
    'male_remaining',   greatest(public.event_capacity() - count(*) filter (where gender='male'   and status='confirmed'), 0),
    'female_remaining', greatest(public.event_capacity() - count(*) filter (where gender='female' and status='confirmed'), 0)
  )
  from public.event_registrations where event_id = p_event_id;
$$;

-- ---------- Admin list (secret-gated; for the simple admin page) ----------
-- This repo is PUBLIC and GitHub Pages serves it, so the real secret must
-- never be committed here. Substitute it at deploy time. Left unsubstituted,
-- the function refuses every call rather than shipping a publicly known secret.
-- This one returns names, emails and phone numbers — treat the secret as a password.
create or replace function public.event_admin_list(p_secret text, p_event_id text default 'launch_2026_06_27')
returns setof public.event_registrations
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
    select * from public.event_registrations
     where event_id = p_event_id
     order by gender, (status='confirmed') desc, created_at;
end $$;

-- ---------- Grants ----------
grant execute on function public.event_register(text,text,text,text,boolean,boolean,text) to anon, authenticated;
grant execute on function public.event_cancel(uuid)                                       to anon, authenticated;
grant execute on function public.event_availability(text)                                 to anon, authenticated;
grant execute on function public.event_admin_list(text,text)                              to anon, authenticated;
