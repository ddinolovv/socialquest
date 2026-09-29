-- Run after schema.sql and moderation.sql.
-- Afterward, make your own account admin with:
-- update public.profiles set is_admin = true where username = 'YOUR_USERNAME';

alter table public.profiles add column if not exists is_admin boolean not null default false;
alter table public.posts add column if not exists hidden boolean not null default false;

create or replace function public.is_admin()
returns boolean language sql stable security definer set search_path = public as $$
  select coalesce((select is_admin from public.profiles where id = auth.uid()), false);
$$;

drop policy if exists "Posts are visible" on public.posts;
create policy "Visible posts are public" on public.posts for select using (hidden = false or public.is_admin());
create policy "Admins update posts" on public.posts for update using (public.is_admin()) with check (public.is_admin());
create policy "Admins view reports" on public.reports for select using (public.is_admin());
create policy "Admins update reports" on public.reports for update using (public.is_admin()) with check (public.is_admin());
