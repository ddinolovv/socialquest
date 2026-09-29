-- Run once after badges.sql and admin.sql.
-- Allows admins to grant or remove badges manually.

drop policy if exists "Admins manage user badges" on public.user_badges;
create policy "Admins manage user badges"
on public.user_badges for all
using (public.is_admin())
with check (public.is_admin());
