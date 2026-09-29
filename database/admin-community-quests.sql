-- Run once after group-quests.sql and admin.sql.
-- Allows only admins to create, pause, reset, or delete Community Quests.

drop policy if exists "Admins manage group quests" on public.group_quests;
create policy "Admins manage group quests"
on public.group_quests for all
using (public.is_admin())
with check (public.is_admin());
