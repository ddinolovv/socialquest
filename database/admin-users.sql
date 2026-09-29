-- Run after admin.sql to enable user moderation controls.

alter table public.profiles
  add column if not exists moderation_status text not null default 'active'
    check (moderation_status in ('active', 'warned', 'suspended', 'banned')),
  add column if not exists moderation_note text,
  add column if not exists moderated_at timestamptz;

drop policy if exists "Admins can update profiles" on public.profiles;
create policy "Admins can update profiles"
on public.profiles for update
using (public.is_admin())
with check (public.is_admin());
