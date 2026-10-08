-- All distance calculations are repeated server-side. Client accepts no area/XP input.
create function public.start_activity(p_id uuid,p_started_at timestamptz) returns void
language plpgsql security definer set search_path='' as $$
declare team uuid;begin
  select u.team_id into team from public.users u where u.id=auth.uid() and not u.is_banned;
  if team is null then raise exception 'Team membership required';end if;
  if p_started_at>now()+interval '1 minute' or p_started_at<now()-interval '7 days' then
    raise exception 'Invalid activity start';end if;
  insert into public.activity_sessions(id,user_id,team_id,started_at)
    values(p_id,auth.uid(),team,p_started_at) on conflict(id) do nothing;
  if not exists(select 1 from public.activity_sessions where id=p_id and user_id=auth.uid()) then
    raise exception 'Activity ownership mismatch';end if;
end;$$;

create function public.append_activity_points(p_id uuid,p_offset int,p_points jsonb) returns void
language plpgsql security definer set search_path='' as $$
declare session public.activity_sessions;prev public.activity_points;
  point jsonb;idx int:=0;lat double precision;lng double precision;acc double precision;
  ts timestamptz;spd double precision;dt double precision;meters double precision;
  valid boolean;split boolean;mock boolean;cfg jsonb;
begin
  select * into session from public.activity_sessions where id=p_id and user_id=auth.uid() for update;
  if not found or session.status='blocked' then raise exception 'Activity unavailable';end if;
  if exists(select 1 from public.users where id=auth.uid() and is_banned) then raise exception 'Account blocked';end if;
  if session.status='completed' then return;end if;
  if jsonb_typeof(p_points)<>'array' or jsonb_array_length(p_points)>100 or p_offset<0 then
    raise exception 'Invalid batch';end if;
  if p_offset>(select count(*) from public.activity_points where activity_id=p_id) then
    raise exception 'Missing previous batch';end if;
  select value into cfg from public.app_config where key='game';
  for point in select value from jsonb_array_elements(p_points) loop
    if exists(select 1 from public.activity_points where activity_id=p_id and seq=p_offset+idx) then
      idx:=idx+1;continue;end if;
    lat:=(point->>'latitude')::double precision;lng:=(point->>'longitude')::double precision;
    acc:=(point->>'accuracy')::double precision;ts:=(point->>'timestamp')::timestamptz;
    spd:=coalesce((point->>'speed')::double precision,0);mock:=coalesce((point->>'mocked')::boolean,false);
    if lat is null or lng is null or acc is null or ts is null or
      lat not between -90 and 90 or lng not between -180 and 180 or acc not between 0 and 100000 then
      raise exception 'Invalid coordinate';end if;
    select * into prev from public.activity_points where activity_id=p_id order by seq desc limit 1;
    valid:=acc<=(cfg->>'max_gps_accuracy')::double precision and not mock
      and spd>=0 and spd*3.6<=(cfg->>'max_capture_speed')::double precision
      and ts>=session.started_at and ts<=now()+interval '1 minute';
    split:=prev.seq is null or not prev.accepted;
    if prev.seq is not null then
      dt:=extract(epoch from(ts-prev.timestamp));
      if dt<=0 then valid:=false;
      elsif dt>60 then split:=true;
      else
        meters:=extensions.st_distance(
          extensions.st_setsrid(extensions.st_makepoint(prev.longitude,prev.latitude),4326)::extensions.geography,
          extensions.st_setsrid(extensions.st_makepoint(lng,lat),4326)::extensions.geography);
        if meters/dt*3.6>(cfg->>'max_capture_speed')::double precision then valid:=false;end if;
      end if;
    end if;
    insert into public.activity_points(activity_id,seq,latitude,longitude,timestamp,accuracy,speed,altitude,mocked,accepted,segment_start)
    values(p_id,p_offset+idx,lat,lng,ts,acc,spd,(point->>'altitude')::double precision,mock,coalesce(valid,false),split);
    idx:=idx+1;
  end loop;
end;$$;

create function public.finish_activity(p_id uuid,p_ended_at timestamptz,p_reported_steps int default null) returns void
language plpgsql security definer set search_path='' as $$
declare session public.activity_sessions;dist double precision;invalid_count int;point_count int;
begin
  select * into session from public.activity_sessions where id=p_id and user_id=auth.uid() for update;
  if not found or session.status='blocked' then raise exception 'Activity unavailable';end if;
  if exists(select 1 from public.users where id=auth.uid() and is_banned) then raise exception 'Account blocked';end if;
  if session.status='completed' then return;end if;
  if p_ended_at<session.started_at or p_ended_at>now()+interval '1 minute' or
    p_reported_steps<0 or p_reported_steps>200000 or
    p_ended_at<(select max(timestamp) from public.activity_points where activity_id=p_id and accepted) then
    raise exception 'Invalid activity finish';end if;
  with pairs as (
    select p.*,lag(latitude) over(order by seq) as prev_lat,lag(longitude) over(order by seq) as prev_lng,
      lag(accepted) over(order by seq) as prev_ok from public.activity_points p where activity_id=p_id
  ) select coalesce(sum(extensions.st_distance(
    extensions.st_setsrid(extensions.st_makepoint(longitude,latitude),4326)::extensions.geography,
    extensions.st_setsrid(extensions.st_makepoint(prev_lng,prev_lat),4326)::extensions.geography)),0)
    into dist from pairs where accepted and prev_ok and not segment_start;
  select count(*),count(*) filter(where not accepted) into point_count,invalid_count
    from public.activity_points where activity_id=p_id;
  update public.activity_sessions set ended_at=p_ended_at,status='completed',distance=dist,
    duration=extract(epoch from(p_ended_at-started_at))::int,
    average_speed=case when p_ended_at>started_at then dist/extract(epoch from(p_ended_at-started_at))*3.6 else 0 end,
    reported_steps=p_reported_steps,is_valid=point_count>=2 and dist>0,
    anti_cheat_score=case when point_count>0 then invalid_count::double precision/point_count else 1 end
    where id=p_id;
  -- Reported Health steps are unverified. No XP, team scores or territory rewards
  -- are issued until the next milestone adds attestation and capture validation.
end;$$;
revoke all on function public.start_activity(uuid,timestamptz),
  public.append_activity_points(uuid,int,jsonb),public.finish_activity(uuid,timestamptz,int) from public;
grant execute on function public.start_activity(uuid,timestamptz),
  public.append_activity_points(uuid,int,jsonb),public.finish_activity(uuid,timestamptz,int) to authenticated;
