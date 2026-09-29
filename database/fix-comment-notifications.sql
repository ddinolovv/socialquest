-- Fix comment publishing when an older generic notification trigger is installed.
-- Run this once in Supabase SQL Editor.

do $$
declare trigger_name text;
begin
  -- Remove only old comment triggers that call the incompatible generic function.
  for trigger_name in
    select t.tgname
    from pg_trigger t
    join pg_proc p on p.oid = t.tgfoid
    where t.tgrelid = 'public.comments'::regclass
      and not t.tgisinternal
      and (
        p.proname = 'create_notification'
        or p.prosrc ilike '%new.user_id%'
      )
  loop
    execute format('drop trigger if exists %I on public.comments', trigger_name);
  end loop;
end;
$$;

create or replace function public.notify_comment()
returns trigger language plpgsql security definer set search_path = public as $$
declare owner_id uuid;
begin
  select author_id into owner_id from public.posts where id = new.post_id;
  if owner_id is not null and owner_id <> new.author_id then
    insert into public.notifications(recipient_id, actor_id, kind, entity_id)
    values(owner_id, new.author_id, 'comment', new.post_id);
  end if;
  return new;
end;
$$;

drop trigger if exists comment_notification on public.comments;
create trigger comment_notification
after insert on public.comments
for each row execute procedure public.notify_comment();

-- Refresh the API schema cache immediately after the repair.
notify pgrst, 'reload schema';
