-- Vendor security migration (run after supabase_schema.sql).
-- IMPORTANT: this migration moves authorization to Supabase Auth. Do not use
-- the old `public_full_access` policies in a production project.

alter table public.app_users add column if not exists auth_user_id uuid unique references auth.users(id) on delete cascade;
alter table public.app_users add column if not exists role text not null default 'user'
  check (role in ('user', 'vendor', 'admin'));
alter table public.products add column if not exists vendor_username text not null default ''
  references public.app_users(username);
alter table public.feedback add column if not exists product_id bigint references public.products(id) on delete cascade;

-- Orders deliberately retain a complete product snapshot. This makes a
-- vendor's historical order readable after a product name or price changes.
create or replace function public.current_role() returns text
language sql stable security definer set search_path = public as $$
  select coalesce((select role from public.app_users where auth_user_id = auth.uid()), 'user')
$$;
create or replace function public.current_username() returns text
language sql stable security definer set search_path = public as $$
  select coalesce((select username from public.app_users where auth_user_id = auth.uid()), '')
$$;

-- Views use security_invoker so the caller's RLS restrictions always apply.
create or replace view public.vendor_orders with (security_invoker = true) as
  select o.* from public.orders o
  where public.current_role() in ('vendor', 'admin')
    and (public.current_role() = 'admin' or exists (
      select 1 from jsonb_array_elements(o.items) item
      where item #>> '{product,vendorUsername}' = public.current_username()));
create or replace view public.vendor_feedback with (security_invoker = true) as
  select f.* from public.feedback f join public.products p on p.id = f.product_id
  where public.current_role() = 'admin' or p.vendor_username = public.current_username();

alter table public.products enable row level security;
alter table public.orders enable row level security;
alter table public.feedback enable row level security;
alter table public.app_users enable row level security;

drop policy if exists "public_full_access" on public.products;
drop policy if exists "public_full_access" on public.orders;
drop policy if exists "public_full_access" on public.feedback;
drop policy if exists "public_full_access" on public.app_users;

create policy "catalog readable" on public.products for select using (true);
create policy "admins manage all products" on public.products for all
  using (public.current_role() = 'admin') with check (public.current_role() = 'admin');
create policy "vendors add own products" on public.products for insert
  with check (public.current_role() = 'vendor' and vendor_username = public.current_username());
create policy "vendors manage own products" on public.products for update
  using (public.current_role() = 'vendor' and vendor_username = public.current_username())
  with check (vendor_username = public.current_username());
create policy "vendors delete own products" on public.products for delete
  using (public.current_role() = 'vendor' and vendor_username = public.current_username());

create policy "buyers create own orders" on public.orders for insert
  with check (owner = public.current_username());
create policy "buyers read own orders" on public.orders for select
  using (owner = public.current_username() or public.current_role() = 'admin'
    or (public.current_role() = 'vendor' and exists (
      select 1 from jsonb_array_elements(items) item
      where item #>> '{product,vendorUsername}' = public.current_username())));
create policy "admins update orders" on public.orders for update
  using (public.current_role() = 'admin') with check (public.current_role() = 'admin');

create policy "signed-in users add feedback" on public.feedback for insert
  with check (owner = public.current_username());
create policy "vendors read product feedback" on public.feedback for select
  using (public.current_role() = 'admin' or exists (select 1 from public.products p
    where p.id = product_id and p.vendor_username = public.current_username()));

create policy "users read own profile" on public.app_users for select
  using (auth_user_id = auth.uid() or public.current_role() = 'admin');
create policy "users create own profile" on public.app_users for insert
  with check (auth_user_id = auth.uid() and role = 'user');
create policy "admins manage profiles" on public.app_users for all
  using (public.current_role() = 'admin') with check (public.current_role() = 'admin');

-- Existing accounts need a Supabase Auth user created and then linked before
-- enabling these policies. New registrations must insert auth_user_id from
-- `SupabaseClient.auth.currentUser!.id`; never store password hashes in
-- app_users. Enable email confirmation only after the app handles it.
notify pgrst, 'reload schema';
