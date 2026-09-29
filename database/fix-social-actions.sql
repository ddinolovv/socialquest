-- Run once in Supabase SQL Editor.
-- Removes obsolete generic notification triggers that can block posts and likes.

do $$
declare table_name text;
declare trigger_name text;
begin
  foreach table_name in array array['posts','comments','post_reactions','follows'] loop
    for trigger_name in
      select t.tgname
      from pg_trigger t
      join pg_proc p on p.oid=t.tgfoid
      where t.tgrelid=format('public.%I',table_name)::regclass
        and not t.tgisinternal
        and p.proname='create_notification'
    loop
      execute format('drop trigger if exists %I on public.%I',trigger_name,table_name);
    end loop;
  end loop;
end;
$$;

-- Ensure the standard write policies exist.
alter table public.posts enable row level security;
alter table public.post_reactions enable row level security;

grant select, insert on table public.posts to authenticated;
grant select, insert, delete on table public.post_reactions to authenticated;

drop policy if exists "Users create their own posts" on public.posts;
create policy "Users create their own posts" on public.posts
for insert to authenticated with check ((select auth.uid())=author_id);

drop policy if exists "Users manage their own reactions" on public.post_reactions;
create policy "Users manage their own reactions" on public.post_reactions
for all to authenticated using ((select auth.uid())=user_id) with check ((select auth.uid())=user_id);

drop policy if exists "Anyone can read posts" on public.posts;
create policy "Anyone can read posts" on public.posts
for select using (true);

drop policy if exists "Anyone can read reactions" on public.post_reactions;
create policy "Anyone can read reactions" on public.post_reactions
for select using (true);

notify pgrst, 'reload schema';
