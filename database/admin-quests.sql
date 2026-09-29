-- Run after admin.sql to allow admins to manage quests.

drop policy if exists "Admins manage quests" on public.quests;
create policy "Admins manage quests"
on public.quests for all
using (public.is_admin())
with check (public.is_admin());
