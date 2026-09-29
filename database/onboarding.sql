-- Run after schema.sql.
alter table public.profiles add column if not exists interests text[] not null default '{}';
alter table public.profiles add column if not exists onboarding_completed boolean not null default false;
