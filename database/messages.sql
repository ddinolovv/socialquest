-- Run after schema.sql. Private direct messages for SocialQuest.

create table public.conversations (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now()
);
create table public.conversation_members (
  conversation_id uuid references public.conversations(id) on delete cascade,
  user_id uuid references public.profiles(id) on delete cascade,
  joined_at timestamptz not null default now(),
  last_read_at timestamptz not null default now(),
  primary key (conversation_id, user_id)
);
create table public.messages (
  id uuid primary key default gen_random_uuid(),
  conversation_id uuid not null references public.conversations(id) on delete cascade,
  sender_id uuid not null references public.profiles(id) on delete cascade,
  body text not null check (char_length(body) between 1 and 2000),
  created_at timestamptz not null default now()
);
create index messages_conversation_created_idx on public.messages(conversation_id, created_at);

create schema if not exists app_private;
revoke all on schema app_private from public;
grant usage on schema app_private to authenticated;

create or replace function app_private.is_conversation_member(target_conversation uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists(select 1 from public.conversation_members where conversation_id = target_conversation and user_id = auth.uid());
$$;

create or replace function public.get_or_create_direct_conversation(recipient_id uuid)
returns uuid language plpgsql security definer set search_path = public as $$
declare conversation uuid;
begin
  if auth.uid() is null or recipient_id = auth.uid() then raise exception 'Invalid recipient'; end if;
  select mine.conversation_id into conversation from public.conversation_members mine
  where mine.user_id = auth.uid() and exists(
    select 1 from public.conversation_members other where other.conversation_id = mine.conversation_id and other.user_id = recipient_id
  ) limit 1;
  if conversation is null then
    insert into public.conversations default values returning id into conversation;
    insert into public.conversation_members(conversation_id,user_id) values(conversation,auth.uid()),(conversation,recipient_id);
  end if;
  return conversation;
end;
$$;

alter table public.conversations enable row level security;
alter table public.conversation_members enable row level security;
alter table public.messages enable row level security;
create policy "Members see their conversations" on public.conversations for select to authenticated using ((select app_private.is_conversation_member(id)));
create policy "Members see conversation members" on public.conversation_members for select to authenticated using ((select app_private.is_conversation_member(conversation_id)));
create policy "Members update their own read state" on public.conversation_members for update to authenticated using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));
create policy "Members see messages" on public.messages for select to authenticated using ((select app_private.is_conversation_member(conversation_id)));
create policy "Members send messages" on public.messages for insert to authenticated with check (sender_id = (select auth.uid()) and (select app_private.is_conversation_member(conversation_id)));

alter table public.messages replica identity full;
create index if not exists conversation_members_user_read_idx on public.conversation_members(user_id, last_read_at);
do $$ begin
  alter publication supabase_realtime add table public.messages;
exception when duplicate_object then null;
end $$;

revoke all on function app_private.is_conversation_member(uuid) from public, anon;
grant execute on function app_private.is_conversation_member(uuid) to authenticated;
revoke execute on function public.get_or_create_direct_conversation(uuid) from public, anon;
grant execute on function public.get_or_create_direct_conversation(uuid) to authenticated;
