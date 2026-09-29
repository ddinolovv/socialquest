-- SocialQuest database schema for Supabase (PostgreSQL)
-- Run this in the Supabase SQL Editor after creating a project.

create extension if not exists "pgcrypto";

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  username text unique not null check (username ~ '^[a-z0-9_]{3,30}$'),
  display_name text not null check (char_length(display_name) between 2 and 50),
  avatar_url text,
  bio text check (char_length(bio) <= 160),
  xp integer not null default 0 check (xp >= 0),
  level integer not null default 1 check (level >= 1),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.posts (
  id uuid primary key default gen_random_uuid(),
  author_id uuid not null references public.profiles(id) on delete cascade,
  body text not null check (char_length(body) between 1 and 2000),
  image_url text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.comments (
  id uuid primary key default gen_random_uuid(),
  post_id uuid not null references public.posts(id) on delete cascade,
  author_id uuid not null references public.profiles(id) on delete cascade,
  body text not null check (char_length(body) between 1 and 1000),
  created_at timestamptz not null default now()
);

create table public.post_reactions (
  post_id uuid references public.posts(id) on delete cascade,
  user_id uuid references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (post_id, user_id)
);

create table public.follows (
  follower_id uuid references public.profiles(id) on delete cascade,
  following_id uuid references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (follower_id, following_id),
  check (follower_id <> following_id)
);

create table public.quests (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  description text not null,
  icon text not null default '✨',
  xp_reward integer not null check (xp_reward > 0),
  goal integer not null default 1 check (goal > 0),
  cadence text not null default 'daily' check (cadence in ('daily', 'weekly', 'one_time')),
  active boolean not null default true,
  created_at timestamptz not null default now()
);

create table public.user_quests (
  user_id uuid references public.profiles(id) on delete cascade,
  quest_id uuid references public.quests(id) on delete cascade,
  progress integer not null default 0 check (progress >= 0),
  completed_at timestamptz,
  period_start date not null default current_date,
  primary key (user_id, quest_id, period_start)
);

create table public.notifications (
  id uuid primary key default gen_random_uuid(),
  recipient_id uuid not null references public.profiles(id) on delete cascade,
  actor_id uuid references public.profiles(id) on delete cascade,
  kind text not null check (kind in ('reaction', 'comment', 'follow', 'quest')),
  entity_id uuid,
  read_at timestamptz,
  created_at timestamptz not null default now()
);

create index posts_author_created_idx on public.posts(author_id, created_at desc);
create index posts_created_idx on public.posts(created_at desc);
create index comments_post_created_idx on public.comments(post_id, created_at);
create index notifications_recipient_idx on public.notifications(recipient_id, created_at desc);

-- Profile is created automatically whenever a new user verifies their email.
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles (id, username, display_name)
  values (
    new.id,
    coalesce(nullif(lower(regexp_replace(new.raw_user_meta_data ->> 'username', '[^a-zA-Z0-9_]', '', 'g')), ''), 'quester_' || substr(new.id::text, 1, 8)),
    coalesce(nullif(new.raw_user_meta_data ->> 'display_name', ''), 'New Quester')
  );
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();

alter table public.profiles enable row level security;
alter table public.posts enable row level security;
alter table public.comments enable row level security;
alter table public.post_reactions enable row level security;
alter table public.follows enable row level security;
alter table public.quests enable row level security;
alter table public.user_quests enable row level security;
alter table public.notifications enable row level security;

create policy "Public profiles are visible" on public.profiles for select using (true);
create policy "Users update their own profile" on public.profiles for update using (auth.uid() = id) with check (auth.uid() = id);
create policy "Posts are visible" on public.posts for select using (true);
create policy "Users create their own posts" on public.posts for insert with check (auth.uid() = author_id);
create policy "Users update their own posts" on public.posts for update using (auth.uid() = author_id) with check (auth.uid() = author_id);
create policy "Users delete their own posts" on public.posts for delete using (auth.uid() = author_id);
create policy "Comments are visible" on public.comments for select using (true);
create policy "Users create their own comments" on public.comments for insert with check (auth.uid() = author_id);
create policy "Users delete their own comments" on public.comments for delete using (auth.uid() = author_id);
create policy "Reactions are visible" on public.post_reactions for select using (true);
create policy "Users manage their own reactions" on public.post_reactions for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "Follows are visible" on public.follows for select using (true);
create policy "Users manage their own follows" on public.follows for all using (auth.uid() = follower_id) with check (auth.uid() = follower_id);
create policy "Active quests are visible" on public.quests for select using (active = true);
create policy "Users see their own quest progress" on public.user_quests for select using (auth.uid() = user_id);
create policy "Users change their own quest progress" on public.user_quests for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "Users see their own notifications" on public.notifications for select using (auth.uid() = recipient_id);
create policy "Users update their own notifications" on public.notifications for update using (auth.uid() = recipient_id) with check (auth.uid() = recipient_id);

insert into public.quests (title, description, icon, xp_reward, goal, cadence) values
  ('Voice of the community', 'Leave 2 helpful comments', '💬', 50, 2, 'daily'),
  ('Capture the moment', 'Share a photo from your day', '📸', 35, 1, 'daily'),
  ('New ally', 'Follow someone new', '🤝', 25, 1, 'daily');
