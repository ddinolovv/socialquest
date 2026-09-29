-- Run after gamification.sql and admin-quests.sql.
-- Adds a machine-checkable action to every quest.

alter table public.quests
  add column if not exists action_type text not null default 'post'
  check (action_type in ('post', 'comment', 'follow'));

update public.quests set action_type = 'comment' where title = 'Voice of the community';
update public.quests set action_type = 'follow' where title = 'New ally';
update public.quests set action_type = 'post' where title = 'Capture the moment';

create or replace function public.advance_quest(player_id uuid, quest_title text)
returns void language plpgsql security definer set search_path = public as $$
declare
  selected_quest public.quests%rowtype;
  progress_row public.user_quests%rowtype;
  award_xp integer;
begin
  for selected_quest in select * from public.quests where active = true and action_type = quest_title loop
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

      if progress_row.progress + 1 >= selected_quest.goal then
        update public.profiles set xp = xp + selected_quest.xp_reward,
          level = ((xp + selected_quest.xp_reward) / 3000) + 1,
          updated_at = now() where id = player_id;
      end if;
    end if;
  end loop;
end;
$$;

create or replace function public.quest_for_post()
returns trigger language plpgsql security definer set search_path = public as $$
begin perform public.advance_quest(new.author_id, 'post'); return new; end; $$;
create or replace function public.quest_for_comment()
returns trigger language plpgsql security definer set search_path = public as $$
begin perform public.advance_quest(new.author_id, 'comment'); return new; end; $$;
create or replace function public.quest_for_follow()
returns trigger language plpgsql security definer set search_path = public as $$
begin perform public.advance_quest(new.follower_id, 'follow'); return new; end; $$;
