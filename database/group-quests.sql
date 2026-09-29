-- Run after schema.sql and gamification.sql.

create table public.group_quests (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  description text not null,
  goal integer not null check (goal > 0),
  progress integer not null default 0 check (progress >= 0),
  xp_reward integer not null check (xp_reward > 0),
  active boolean not null default true,
  created_at timestamptz not null default now()
);
create table public.group_quest_members (
  group_quest_id uuid references public.group_quests(id) on delete cascade,
  user_id uuid references public.profiles(id) on delete cascade,
  joined_at timestamptz not null default now(),
  contributions integer not null default 0,
  primary key(group_quest_id,user_id)
);
alter table public.group_quests enable row level security;
alter table public.group_quest_members enable row level security;
create policy "Group quests are visible" on public.group_quests for select using (true);
create policy "Members are visible" on public.group_quest_members for select using (true);
create policy "Users join as themselves" on public.group_quest_members for insert with check (user_id = auth.uid());

create or replace function public.join_group_quest(quest_id uuid)
returns void language plpgsql security definer set search_path = public as $$
begin
  insert into public.group_quest_members(group_quest_id,user_id) values(quest_id,auth.uid()) on conflict do nothing;
end; $$;

create or replace function public.contribute_to_group_quests(player_id uuid)
returns void language plpgsql security definer set search_path = public as $$
declare q public.group_quests%rowtype;
begin
  for q in select * from public.group_quests where active=true for update loop
    if exists(select 1 from public.group_quest_members where group_quest_id=q.id and user_id=player_id) then
      update public.group_quest_members set contributions=contributions+1 where group_quest_id=q.id and user_id=player_id;
      update public.group_quests set progress=progress+1 where id=q.id;
      if q.progress+1 >= q.goal then
        update public.group_quests set active=false where id=q.id;
        update public.profiles set xp=xp+q.xp_reward,level=((xp+q.xp_reward)/3000)+1 where id in (select user_id from public.group_quest_members where group_quest_id=q.id);
      end if;
    end if;
  end loop;
end; $$;

create or replace function public.group_quest_post_contribution()
returns trigger language plpgsql security definer set search_path = public as $$
begin perform public.contribute_to_group_quests(new.author_id); return new; end; $$;
drop trigger if exists group_quest_post on public.posts;
create trigger group_quest_post after insert on public.posts for each row execute procedure public.group_quest_post_contribution();

insert into public.group_quests(title,description,goal,xp_reward)
select 'Community Spark','Together, publish 20 new stories in SocialQuest.',20,100
where not exists(select 1 from public.group_quests where title='Community Spark');
