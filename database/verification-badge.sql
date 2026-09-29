-- Run once after badges.sql, admin.sql and admin-badges.sql.

alter table public.profiles add column if not exists is_verified boolean not null default false;

insert into public.badges(code,name,description,icon,sort_order)
values ('verified','Verified','Officially verified by the SocialQuest team.','✓',0)
on conflict (code) do update set name=excluded.name,description=excluded.description,icon=excluded.icon,sort_order=excluded.sort_order;

create or replace function public.sync_verification_badge()
returns trigger language plpgsql security definer set search_path=public as $$
declare target_user uuid; target_badge uuid; is_verification boolean;
begin
  target_user := coalesce(new.user_id,old.user_id);
  target_badge := coalesce(new.badge_id,old.badge_id);
  select code='verified' into is_verification from public.badges where id=target_badge;
  if is_verification then
    update public.profiles set is_verified = exists(
      select 1 from public.user_badges ub join public.badges b on b.id=ub.badge_id
      where ub.user_id=target_user and b.code='verified'
    ) where id=target_user;
  end if;
  return coalesce(new,old);
end; $$;

drop trigger if exists sync_verification_badge_on_award on public.user_badges;
create trigger sync_verification_badge_on_award
after insert or delete on public.user_badges
for each row execute procedure public.sync_verification_badge();

update public.profiles p set is_verified=exists(
  select 1 from public.user_badges ub join public.badges b on b.id=ub.badge_id
  where ub.user_id=p.id and b.code='verified'
);
