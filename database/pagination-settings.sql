-- SocialQuest pagination defaults. Run this once in Supabase SQL Editor.
-- Admins can later change a value, for example:
-- update app_settings set value = 10 where key = 'posts_per_page';

create table if not exists public.app_settings (
  key text primary key,
  value integer not null check (value between 5 and 50),
  updated_at timestamptz not null default now()
);

alter table public.profiles add column if not exists is_admin boolean not null default false;

insert into public.app_settings (key, value)
values ('posts_per_page', 5), ('profiles_per_page', 5)
on conflict (key) do nothing;

alter table public.app_settings enable row level security;

drop policy if exists "Anyone can read app settings" on public.app_settings;
create policy "Anyone can read app settings"
on public.app_settings for select using (true);

drop policy if exists "Admins can update app settings" on public.app_settings;
create policy "Admins can update app settings"
on public.app_settings for update
using (exists (select 1 from public.profiles where id = auth.uid() and is_admin = true))
with check (exists (select 1 from public.profiles where id = auth.uid() and is_admin = true));
