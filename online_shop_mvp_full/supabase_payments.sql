-- ============================================================================
-- Payment verification (KHQR / Bakong) — run AFTER supabase_schema.sql and
-- supabase_vendor_security.sql.
--
-- HOW TO INSTALL (one time):
--   1. Open https://supabase.com/dashboard → your project
--   2. Left menu → SQL Editor → New query
--   3. Paste this whole file and click RUN
--   4. Set the Bakong token: Project Settings → Edge Functions → Secrets
--        BAKONG_API_TOKEN = <your token from bakong.nbc.org.kh developers>
--      (or run the last statement of this file from the SQL Editor while
--      logged in as a role allowed to alter vault secrets.)
--
-- WHAT IT DOES
--   * `payments` table: one PENDING row per vendor share of a checkout
--     reference, created by the app when the QR sheet opens.
--   * `verify_payment(reference)`: asks the Bakong Open API
--     (POST https://api-bakong.nbc.gov.kh/v1/check_transaction_by_md5,
--     Authorization: Bearer <BAKONG_API_TOKEN>) for EVERY pending payment
--     of that reference. The MD5 hash it checks is the md5 of the exact QR
--     string the app displayed. A response code of 0 marks that share
--     VERIFIED (amount + currency recorded); anything else stays pending.
--     Opening the QR, scanning it, or simply calling this function NEVER
--     verifies anything — only the provider's "transaction found" answer does.
--   * `create_verified_order(reference, ...)`: the ONLY way the app creates
--     an order now. Re-checks every payment with Bakong server-side and
--     refuses (raises) unless every share is VERIFIED. Idempotent: reusing
--     a reference returns the existing order id instead of a second order,
--     so double-clicking the button can never double-order.
-- ============================================================================

-- --------------------------------------------------------------- payments --
create table if not exists public.payments (
  reference    text not null,
  vendor       text not null default 'store',
  amount       numeric not null default 0,
  currency     text not null default 'USD',
  qr_md5       text not null default '',
  qr_payload   text not null default '',
  status       text not null default 'PENDING'
               check (status in ('PENDING', 'VERIFIED')),
  verified_at  timestamptz,
  bakong_hash  text,
  created_at   timestamptz not null default now(),
  primary key (reference, vendor)
);

alter table public.payments enable row level security;

drop policy if exists "payments_anon_full" on public.payments;
create policy "payments_anon_full" on public.payments
  for all to anon, authenticated using (true) with check (true);

alter publication supabase_realtime add table public.payments;

-- ------------------------------------------------------------- bakong call --
-- Server-side verification against the provider. Returns true only when the
-- provider confirms the transaction for that exact QR hash.
create or replace function public.bakong_transaction_paid(p_md5 text)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  v_token  text;
  v_res    jsonb;
  v_code   int;
  v_url    text := 'https://api-bakong.nbc.gov.kh/v1/check_transaction_by_md5';
begin
  select decrypted_secret into v_token from vault.decrypted_secrets
    where name = 'BAKONG_API_TOKEN' limit 1;
  if v_token is null or v_token = '' then
    -- Not configured: verification CANNOT pass. Never fail open.
    return false;
  end if;

  begin
    select http_post(
             v_url,
             json_build_object('md5', p_md5)::text,
             'application/json',
             'Authorization: Bearer ' || v_token
           )::jsonb
      into v_res;
  exception when others then
    return false; -- network/server error = unverified, never verified
  end;

  if v_res is null then
    return false;
  end if;

  -- Bakong: responseCode 0 = success (transaction found & completed).
  v_code := coalesce((v_res ->> 'responseCode')::int, -1);
  return v_code = 0;
end $$;

-- Requires the pg_net + http extensions (bundled with Supabase). Enable via:
--   create extension if not exists pg_net;
--   create extension if not exists http;      -- schema "http" (supabase)
-- (Both are idempotent — safe to re-run. On hosted Supabase, enable "http"
--  under Database → Extensions; pg_net is usually already on.)

-- ------------------------------------------------------------ verification --
-- Re-checks every pending payment share of the reference against Bakong.
-- Returns true only when EVERY share is VERIFIED afterwards.
create or replace function public.verify_payment(p_reference text)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  r         record;
  v_paid    boolean;
  v_pending int := 0;
begin
  if p_reference is null or p_reference = '' then
    return false;
  end if;

  for r in
    select * from public.payments
     where reference = p_reference and status = 'PENDING'
  loop
    if r.qr_md5 = '' then
      v_pending := v_pending + 1;
      continue; -- no QR hash recorded — nothing to verify
    end if;

    v_paid := public.bakong_transaction_paid(r.qr_md5);
    if v_paid then
      update public.payments
         set status = 'VERIFIED', verified_at = now()
       where reference = r.reference and vendor = r.vendor;
    else
      v_pending := v_pending + 1;
    end if;
  end loop;

  select count(*) into v_pending
    from public.payments
   where reference = p_reference and status = 'PENDING';

  return v_pending = 0;
end $$;

-- ------------------------------------------------------- order creation ----
-- The ONLY order path for QR payments. Server-side re-verification: an order
-- is created only if every payment share of the reference is VERIFIED (after
-- a fresh Bakong re-check). Idempotent per reference → no duplicate orders.
create or replace function public.create_verified_order(
  p_reference    text,
  p_owner        text,
  p_total        numeric,
  p_address      text,
  p_items        jsonb)
returns text            -- the order id, existing or newly created
language plpgsql
security definer
set search_path = public
as $$
declare
  v_existing  text;
  v_pending   int;
  v_order_id  text;
begin
  -- 1. Duplicate protection: same reference → return the SAME order.
  select id into v_existing from public.orders where id = p_reference limit 1;
  if v_existing is not null then
    return v_existing;
  end if;

  -- 2. Server-side verification: re-check pending shares with Bakong.
  perform public.verify_payment(p_reference);
  select count(*) into v_pending
    from public.payments
   where reference = p_reference and status = 'PENDING';
  if v_pending > 0 then
    raise exception 'PAYMENT_NOT_VERIFIED';
  end if;

  -- 3. No payment rows at all → nothing was ever registered → reject.
  if not exists (select 1 from public.payments where reference = p_reference) then
    raise exception 'PAYMENT_NOT_VERIFIED';
  end if;

  -- 4. Create the order (id = the checkout reference → naturally idempotent).
  v_order_id := p_reference;
  insert into public.orders (id, owner, status, total, address, items)
  values (v_order_id,
          coalesce(p_owner, ''),
          'Processing',
          p_total,
          coalesce(p_address, ''),
          coalesce(p_items, '[]'::jsonb));

  return v_order_id;
end $$;

-- ----------------------------------------------------------------------------
-- BAKONG_API_TOKEN secret: create it in Vault with the statement below (run in
-- the SQL Editor), replacing <TOKEN> with your Bakong developer token:
--
--   select vault.create_secret('<TOKEN>', 'BAKONG_API_TOKEN');
--
-- Until the token is set, verify_payment / create_verified_order stay in
-- "cannot verify" mode: they always report NOT verified (fail closed).
-- ----------------------------------------------------------------------------
