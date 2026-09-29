-- Run after schema.sql. Reporting and blocking foundation.

create table public.reports (
  id uuid primary key default gen_random_uuid(),
  reporter_id uuid not null references public.profiles(id) on delete cascade,
  post_id uuid references public.posts(id) on delete cascade,
  reported_user_id uuid references public.profiles(id) on delete cascade,
  reason text not null check (reason in ('spam','harassment','hate','nudity','other')),
  details text check (char_length(details) <= 500),
  status text not null default 'open' check (status in ('open','reviewing','resolved','dismissed')),
  created_at timestamptz not null default now(),
  check (post_id is not null or reported_user_id is not null)
);
create table public.blocks (
  blocker_id uuid references public.profiles(id) on delete cascade,
  blocked_id uuid references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key(blocker_id,blocked_id),
  check(blocker_id <> blocked_id)
);
alter table public.reports enable row level security;
alter table public.blocks enable row level security;
create policy "Users submit their own reports" on public.reports for insert with check (reporter_id = auth.uid());
create policy "Users see their own reports" on public.reports for select using (reporter_id = auth.uid());
create policy "Users manage their own blocks" on public.blocks for all using (blocker_id = auth.uid()) with check (blocker_id = auth.uid());
create index reports_status_created_idx on public.reports(status,created_at);
