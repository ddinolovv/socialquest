-- Run once in Supabase SQL Editor to enable comment likes and threaded replies.

alter table public.comments
  add column if not exists parent_id uuid references public.comments(id) on delete cascade;

create index if not exists comments_parent_id_idx on public.comments(parent_id);

create table if not exists public.comment_reactions (
  comment_id uuid not null references public.comments(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (comment_id, user_id)
);

alter table public.comment_reactions enable row level security;

drop policy if exists "Anyone can read comment reactions" on public.comment_reactions;
create policy "Anyone can read comment reactions"
on public.comment_reactions for select using (true);

drop policy if exists "Signed-in users can like comments" on public.comment_reactions;
create policy "Signed-in users can like comments"
on public.comment_reactions for insert with check (auth.uid() = user_id);

drop policy if exists "Users can remove their comment likes" on public.comment_reactions;
create policy "Users can remove their comment likes"
on public.comment_reactions for delete using (auth.uid() = user_id);
