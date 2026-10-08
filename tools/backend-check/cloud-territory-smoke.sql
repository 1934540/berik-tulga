-- Run after migrations 202610070004 and 202610070005 in Supabase SQL Editor.
-- A synthetic Auth subject and all gameplay writes are rolled back.
begin;
do $$
declare actor uuid:=gen_random_uuid();walk uuid:=gen_random_uuid();
  started timestamptz:=now()-interval '30 minutes';points jsonb;live jsonb;finished jsonb;repeated jsonb;
begin
  insert into auth.users(id) values(actor);
  update public.users set full_name='Territory verification',username='smoke_'||substr(actor::text,1,8) where id=actor;
  perform set_config('request.jwt.claim.sub',actor::text,true);
  execute 'set local role authenticated';
  perform public.join_default_team();
  perform public.start_activity(walk,started);
  with corners(i,lat,lng) as (values
    (0,44.8491,65.4804),(1,44.8506,65.4812),(2,44.8515,65.4854),
    (3,44.8496,65.4865),(4,44.8474,65.4855),(5,44.8471,65.4826),(6,44.8491,65.4804)),
  edges as (select *,lead(lat) over(order by i) as next_lat,lead(lng) over(order by i) as next_lng from corners),
  fixes as (select i*12+j as n,lat+(next_lat-lat)*j/12 as lat,lng+(next_lng-lng)*j/12 as lng
    from edges cross join generate_series(0,11) j where i<6
    union all select 72,44.8491,65.4804)
  select jsonb_agg(jsonb_build_object('latitude',lat,'longitude',lng,
    'timestamp',started+make_interval(secs=>(n+1)*20),'accuracy',5,'speed',1.3,'mocked',false) order by n)
    into points from fixes;
  live:=public.append_activity_points(walk,0,points);
  if coalesce((live->>'captured_area')::double precision,0)<1000 or
    live->>'capture_status'<>'captured' or jsonb_array_length(live->'territory'->'features')<3 then
    raise exception 'Live territory capture failed';end if;
  if (select count(*) from public.activity_points where activity_id=walk and accepted)<>73 then
    raise exception 'GPS fixture rejected';end if;
  finished:=public.finish_activity(walk,started+interval '1460 seconds',1872);
  repeated:=public.finish_activity(walk,started+interval '1460 seconds',1872);
  if finished<>live or repeated<>finished then raise exception 'Capture result changed on retry';end if;
  if (select captured_area from public.activity_sessions where id=walk)<1000 then
    raise exception 'Capture area not persisted';end if;
  if (select territory_area from public.my_team_summary())<1000 then
    raise exception 'Team area not updated';end if;
  execute 'reset role';
  if exists(select 1 from public.territory_cells c where c.owner_user_id=actor and
    exists(select 1 from public.territory_restrictions r where extensions.st_intersects(r.geometry,c.geometry))) then
    raise exception 'Restricted cell captured';end if;
end;$$;
rollback;
select 'PASS: live capture, 73 accepted fixes, area/ownership/team, idempotent finish; synthetic data rolled back' as verification,
  (select value->>'territory_enabled' from public.app_config where key='game') as territory_enabled,
  (select count(*) from public.territory_restrictions) as exclusions;
