-- Run after schema.sql. This makes quest progress, XP, and levels server-controlled.

create or replace function public.advance_quest(player_id uuid, quest_title text)
returns void language plpgsql security definer set search_path = public as $$
declare
  selected_quest public.quests%rowtype;
  progress_row public.user_quests%rowtype;
  award_xp integer := 0;
begin
  select * into selected_quest from public.quests where title = quest_title and active = true limit 1;
  if selected_quest.id is null then return; end if;

  insert into public.user_quests(user_id, quest_id, progress, period_start)
  values(player_id, selected_quest.id, 0, current_date)
  on conflict (user_id, quest_id, period_start) do nothing;

  select * into progress_row from public.user_quests
  where user_id = player_id and quest_id = selected_quest.id and period_start = current_date
  for update;

  if progress_row.completed_at is null then
    update public.user_quests
    set progress = least(progress + 1, selected_quest.goal),
        completed_at = case when progress + 1 >= selected_quest.goal then now() else null end
    where user_id = player_id and quest_id = selected_quest.id and period_start = current_date;

    if progress_row.progress + 1 >= selected_quest.goal then award_xp := selected_quest.xp_reward; end if;
  end if;

  if award_xp > 0 then
    update public.profiles
    set xp = xp + award_xp,
        level = ((xp + award_xp) / 3000) + 1,
        updated_at = now()
    where id = player_id;
  end if;
end;
$$;

create or replace function public.quest_for_post()
returns trigger language plpgsql security definer set search_path = public as $$
begin perform public.advance_quest(new.author_id, 'Capture the moment'); return new; end; $$;
create or replace function public.quest_for_comment()
returns trigger language plpgsql security definer set search_path = public as $$
begin perform public.advance_quest(new.author_id, 'Voice of the community'); return new; end; $$;
create or replace function public.quest_for_follow()
returns trigger language plpgsql security definer set search_path = public as $$
begin perform public.advance_quest(new.follower_id, 'New ally'); return new; end; $$;

drop trigger if exists quest_on_post on public.posts;
drop trigger if exists quest_on_comment on public.comments;
drop trigger if exists quest_on_follow on public.follows;
create trigger quest_on_post after insert on public.posts for each row execute procedure public.quest_for_post();
create trigger quest_on_comment after insert on public.comments for each row execute procedure public.quest_for_comment();
create trigger quest_on_follow after insert on public.follows for each row execute procedure public.quest_for_follow();
