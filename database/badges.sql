-- Run once in Supabase SQL Editor after schema.sql.
-- Creates automatic achievement badges for SocialQuest.

create table if not exists public.badges (
  id uuid primary key default gen_random_uuid(),
  code text not null unique,
  name text not null,
  description text not null,
  icon text not null,
  sort_order integer not null default 0
);

create table if not exists public.user_badges (
  user_id uuid not null references public.profiles(id) on delete cascade,
  badge_id uuid not null references public.badges(id) on delete cascade,
  earned_at timestamptz not null default now(),
  primary key (user_id,badge_id)
);

alter table public.badges enable row level security;
alter table public.user_badges enable row level security;

drop policy if exists "Badges are visible" on public.badges;
create policy "Badges are visible" on public.badges for select using (true);
drop policy if exists "User badges are visible" on public.user_badges;
create policy "User badges are visible" on public.user_badges for select using (true);

insert into public.badges(code,name,description,icon,sort_order) values
  ('first_post','First Story','Published your first post.','✦',1),
  ('first_comment','Conversation Starter','Wrote your first comment.','💬',2),
  ('first_like','Appreciator','Liked your first post.','♥',3),
  ('social_starter','Social Starter','Followed 5 Questers.','🤝',4),
  ('quest_master','Quest Master','Completed 10 quest goals.','⚔',5),
  ('community_hero','Community Hero','Completed a Community Quest.','🌐',6)
on conflict (code) do update set name=excluded.name,description=excluded.description,icon=excluded.icon,sort_order=excluded.sort_order;

create or replace function public.evaluate_badges(player_id uuid default auth.uid())
returns void language plpgsql security definer set search_path=public as $$
begin
  if player_id is null then return; end if;
  insert into public.user_badges(user_id,badge_id)
  select player_id,b.id from public.badges b
  where (b.code='first_post' and exists(select 1 from public.posts where author_id=player_id))
     or (b.code='first_comment' and exists(select 1 from public.comments where author_id=player_id))
     or (b.code='first_like' and exists(select 1 from public.post_reactions where user_id=player_id))
     or (b.code='social_starter' and (select count(*) from public.follows where follower_id=player_id)>=5)
     or (b.code='quest_master' and (select count(*) from public.user_quests uq join public.quests q on q.id=uq.quest_id where uq.user_id=player_id and uq.progress>=q.goal)>=10)
     or (b.code='community_hero' and exists(select 1 from public.group_quest_members m join public.group_quests g on g.id=m.group_quest_id where m.user_id=player_id and g.active=false))
  on conflict do nothing;
end; $$;

create or replace function public.badge_check_from_row()
returns trigger language plpgsql security definer set search_path=public as $$
declare
  row_data jsonb;
  target_user_id uuid;
begin
  row_data := to_jsonb(new);
  target_user_id := coalesce(
    nullif(row_data ->> 'author_id','')::uuid,
    nullif(row_data ->> 'user_id','')::uuid,
    nullif(row_data ->> 'follower_id','')::uuid
  );

  if target_user_id is not null then
    begin
      perform public.evaluate_badges(target_user_id);
    exception
      when others then
        raise warning 'Badge evaluation failed after insert on %: %', TG_TABLE_NAME, SQLERRM;
    end;
  end if;

  return new;
end; $$;

drop trigger if exists badges_after_post on public.posts;
drop trigger if exists award_badges_after_post on public.posts;
create trigger award_badges_after_post after insert on public.posts for each row execute function public.badge_check_from_row();
drop trigger if exists badges_after_comment on public.comments;
drop trigger if exists award_badges_after_comment on public.comments;
create trigger award_badges_after_comment after insert on public.comments for each row execute function public.badge_check_from_row();
drop trigger if exists badges_after_reaction on public.post_reactions;
drop trigger if exists award_badges_after_reaction on public.post_reactions;
create trigger award_badges_after_reaction after insert on public.post_reactions for each row execute function public.badge_check_from_row();
drop trigger if exists badges_after_follow on public.follows;
drop trigger if exists award_badges_after_follow on public.follows;
create trigger award_badges_after_follow after insert on public.follows for each row execute function public.badge_check_from_row();

revoke execute on function public.evaluate_badges(uuid) from public, anon;
grant execute on function public.evaluate_badges(uuid) to authenticated;
revoke execute on function public.badge_check_from_row() from public, anon, authenticated;
