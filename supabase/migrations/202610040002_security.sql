-- Deny client mutations of all gameplay and audit tables, even with a forged SDK request.
do $$ declare t text; begin
  foreach t in array array['users','teams','team_members','activity_sessions','activity_points',
    'territory_cells','territory_events','daily_stats','leaderboard_scores','achievements',
    'user_achievements','seasons','season_scores','app_config'] loop
    execute format('alter table public.%I enable row level security',t);
    execute format('revoke all on public.%I from anon,authenticated',t);
  end loop;
end $$;
grant select on public.users to authenticated;
grant update(full_name,username,avatar_url,city,gender,birth_date) on public.users to authenticated;
create policy own_profile_read on public.users for select to authenticated using(id=auth.uid());
create policy own_profile_edit on public.users for update to authenticated using(id=auth.uid() and not is_banned) with check(id=auth.uid() and not is_banned);
grant select on public.teams,public.app_config,public.achievements,public.seasons,
  public.season_scores,public.leaderboard_scores,public.leaderboards to authenticated;
create policy read_teams on public.teams for select to authenticated using(true);
create policy read_config on public.app_config for select to authenticated using(true);
create policy read_achievements on public.achievements for select to authenticated using(true);
create policy read_seasons on public.seasons for select to authenticated using(true);
create policy read_season_scores on public.season_scores for select to authenticated using(true);
create policy read_rankings on public.leaderboard_scores for select to authenticated using(true);
grant select on public.team_members,public.activity_sessions,public.activity_points,
  public.daily_stats,public.user_achievements to authenticated;
create policy own_membership on public.team_members for select to authenticated using(user_id=auth.uid());
create policy own_activities on public.activity_sessions for select to authenticated using(user_id=auth.uid());
create policy own_points on public.activity_points for select to authenticated using(exists(
  select 1 from public.activity_sessions s where s.id=activity_id and s.user_id=auth.uid()));
create policy own_stats on public.daily_stats for select to authenticated using(user_id=auth.uid());
create policy own_badges on public.user_achievements for select to authenticated using(user_id=auth.uid());

create function public.join_default_team() returns void
language plpgsql security definer set search_path='' as $$
declare team uuid := '00000000-0000-4000-8000-000000000001';begin
  if auth.uid() is null then raise exception 'Authentication required';end if;
  perform 1 from public.users where id=auth.uid() and not is_banned and full_name<>'' for update;
  if not found then raise exception 'Complete profile first';end if;
  if exists(select 1 from public.team_members where user_id=auth.uid()) then return;end if;
  insert into public.team_members(user_id,team_id) values(auth.uid(),team);
  update public.users set team_id=team where id=auth.uid();
end;$$;
create function public.my_team_summary() returns table(
  name text,members_count bigint,territory_area double precision,total_steps bigint,total_distance double precision)
language sql stable security definer set search_path='' as $$
  select t.name,(select count(*) from public.team_members m where m.team_id=t.id),
    t.territory_area,t.total_steps,t.total_distance from public.teams t
  join public.team_members m on m.team_id=t.id where m.user_id=auth.uid();
$$;
create function public.my_team_members() returns table(full_name text,username text)
language sql stable security definer set search_path='' as $$
  select u.full_name,u.username from public.users u
  join public.team_members m on m.user_id=u.id
  where m.team_id=(select team_id from public.team_members where user_id=auth.uid())
  and not u.is_banned order by u.full_name limit 100;
$$;
revoke all on function public.join_default_team(),public.my_team_summary(),public.my_team_members() from public;
grant execute on function public.join_default_team(),public.my_team_summary(),public.my_team_members() to authenticated;

-- Public avatars use a dedicated bucket; private GPS routes never enter Storage.
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values('avatars','avatars',true,2097152,array['image/jpeg','image/png','image/webp']) on conflict(id) do nothing;
create policy own_avatar_insert on storage.objects for insert to authenticated
with check(bucket_id='avatars' and (storage.foldername(name))[1]=auth.uid()::text);
create policy own_avatar_update on storage.objects for update to authenticated
using(bucket_id='avatars' and (storage.foldername(name))[1]=auth.uid()::text)
with check(bucket_id='avatars' and (storage.foldername(name))[1]=auth.uid()::text);
create policy avatar_read on storage.objects for select to authenticated using(bucket_id='avatars');
