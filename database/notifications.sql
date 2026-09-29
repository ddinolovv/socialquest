-- Run this after schema.sql in the Supabase SQL Editor.
-- It creates notifications automatically on likes, comments and follows.

create or replace function public.create_notification()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  target_user uuid;
  notification_kind text;
  related_entity uuid;
begin
  if tg_table_name = 'post_reactions' then
    select author_id into target_user from public.posts where id = new.post_id;
    notification_kind := 'reaction';
    related_entity := new.post_id;
  elsif tg_table_name = 'comments' then
    select author_id into target_user from public.posts where id = new.post_id;
    notification_kind := 'comment';
    related_entity := new.post_id;
  elsif tg_table_name = 'follows' then
    target_user := new.following_id;
    notification_kind := 'follow';
    related_entity := new.follower_id;
  end if;

  if target_user is not null and target_user <> new.author_id and target_user <> new.user_id and target_user <> new.follower_id then
    insert into public.notifications (recipient_id, actor_id, kind, entity_id)
    values (target_user, coalesce(new.author_id, new.user_id, new.follower_id), notification_kind, related_entity);
  end if;
  return new;
end;
$$;

-- Separate functions avoid referring to columns that do not exist on each table.
create or replace function public.notify_post_reaction()
returns trigger language plpgsql security definer set search_path = public as $$
declare owner_id uuid;
begin select author_id into owner_id from public.posts where id = new.post_id;
  if owner_id <> new.user_id then insert into public.notifications(recipient_id,actor_id,kind,entity_id) values(owner_id,new.user_id,'reaction',new.post_id); end if;
  return new;
end; $$;
create or replace function public.notify_comment()
returns trigger language plpgsql security definer set search_path = public as $$
declare owner_id uuid;
begin select author_id into owner_id from public.posts where id = new.post_id;
  if owner_id <> new.author_id then insert into public.notifications(recipient_id,actor_id,kind,entity_id) values(owner_id,new.author_id,'comment',new.post_id); end if;
  return new;
end; $$;
create or replace function public.notify_follow()
returns trigger language plpgsql security definer set search_path = public as $$
begin insert into public.notifications(recipient_id,actor_id,kind,entity_id) values(new.following_id,new.follower_id,'follow',new.follower_id); return new; end; $$;

drop trigger if exists post_reaction_notification on public.post_reactions;
drop trigger if exists comment_notification on public.comments;
drop trigger if exists follow_notification on public.follows;
create trigger post_reaction_notification after insert on public.post_reactions for each row execute procedure public.notify_post_reaction();
create trigger comment_notification after insert on public.comments for each row execute procedure public.notify_comment();
create trigger follow_notification after insert on public.follows for each row execute procedure public.notify_follow();
