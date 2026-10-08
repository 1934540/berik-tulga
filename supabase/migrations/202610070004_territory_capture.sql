-- Kyzylorda grid: EPSG:32641; hex_size is the edge length/circumradius in metres.
-- RPCs, not client-supplied polygons or area, decide ownership.
alter table public.activity_sessions add column capture_processed_seq int not null default -1;
alter table public.activity_sessions add column capture_status text not null default 'open';
alter table public.territory_cells add column area double precision not null default 0;
update public.territory_cells set area=extensions.st_area(geometry::extensions.geography);
create unique index territory_activity_cell_once on public.territory_events(activity_id,cell_id)
  where activity_id is not null and event_type in ('capture','attack','defend');
create table public.territory_restrictions (
  id text primary key, reason text not null,
  geometry extensions.geometry(Geometry,4326) not null
);
create index territory_restrictions_geometry_idx on public.territory_restrictions using gist(geometry);
alter table public.territory_restrictions enable row level security;
revoke all on public.territory_restrictions from public,anon,authenticated;
update public.app_config set value=value||'{"territory_enabled":true,"maximum_capture_area":2000000}'::jsonb
  where key='game';

create function public.activity_capture_result(p_id uuid) returns jsonb
language sql stable security definer set search_path='' as $$
  select jsonb_build_object(
    'captured_area',s.captured_area,
    'capture_status',case when s.captured_area>0 then 'captured'
      when exists(select 1 from public.territory_events e where e.activity_id=s.id and e.event_type='defend') then 'defended'
      when exists(select 1 from public.territory_events e where e.activity_id=s.id and e.event_type='attack') then 'attacked'
      else s.capture_status end,
    'processed_points',s.capture_processed_seq+1,
    'attacked_cells',(select count(*) from public.territory_events e where e.activity_id=s.id and e.event_type='attack'),
    'defended_cells',(select count(*) from public.territory_events e where e.activity_id=s.id and e.event_type='defend'),
    'territory',jsonb_build_object('type','FeatureCollection','features',coalesce((
      select jsonb_agg(jsonb_build_object('type','Feature','id',c.hex_id,
        'properties',jsonb_build_object('id',c.hex_id,'area',c.area,'hp',c.hp,
          'owner_team_id',c.owner_team_id,'color',coalesce(t.primary_color,'#FF673B')),
        'geometry',extensions.st_asgeojson(c.geometry)::jsonb) order by c.hex_id)
      from public.territory_events e join public.territory_cells c on c.id=e.cell_id
      left join public.teams t on t.id=c.owner_team_id where e.activity_id=s.id
        and e.event_type in ('capture','attack','defend')
    ),'[]'::jsonb)))
  from public.activity_sessions s where s.id=p_id and s.user_id=auth.uid();
$$;

create function public.process_activity_capture(p_id uuid) returns jsonb
language plpgsql security definer set search_path='' as $$
declare s public.activity_sessions;cfg jsonb;endpoint public.activity_points;anchor record;
  cell public.territory_cells;line extensions.geometry;polygon extensions.geometry;
  projected extensions.geometry;segment_first int;last_seq int;new_hp int;event_kind text;
  gained double precision:=0;defended_today int;before_team uuid;before_user uuid;
  changed boolean:=false;affected record;affected_users uuid[];cell_count int;
begin
  select * into s from public.activity_sessions where id=p_id and user_id=auth.uid() for update;
  if not found or s.status='blocked' then raise exception 'Activity unavailable';end if;
  if exists(select 1 from public.users where id=auth.uid() and is_banned) then raise exception 'Account blocked';end if;
  if s.status='completed' then return public.activity_capture_result(p_id);end if;
  select value into cfg from public.app_config where key='game';
  if not coalesce((cfg->>'territory_enabled')::boolean,false) then
    update public.activity_sessions set capture_status='disabled' where id=p_id;
    return public.activity_capture_result(p_id);
  end if;
  affected_users:=array[s.user_id];
  select coalesce(max(seq),-1) into last_seq from public.activity_points where activity_id=p_id;
  for endpoint in select * from public.activity_points where activity_id=p_id
    and seq>s.capture_processed_seq order by seq loop
    if not endpoint.accepted then continue;end if;
    select coalesce(max(seq),0) into segment_first from public.activity_points where activity_id=p_id
      and seq<=endpoint.seq and (segment_start or not accepted);
    for anchor in select p.seq from public.activity_points p where p.activity_id=p_id
      and p.seq>=segment_first and p.seq<=endpoint.seq-3 and p.accepted
      and extensions.st_distance(
        extensions.st_setsrid(extensions.st_makepoint(p.longitude,p.latitude),4326)::extensions.geography,
        extensions.st_setsrid(extensions.st_makepoint(endpoint.longitude,endpoint.latitude),4326)::extensions.geography
      )<=(cfg->>'closure_distance')::double precision order by p.seq loop
      select extensions.st_removerepeatedpoints(extensions.st_makeline(
        extensions.st_setsrid(extensions.st_makepoint(p.longitude,p.latitude),4326) order by seq))
        into line from public.activity_points p where p.activity_id=p_id and p.seq between anchor.seq and endpoint.seq;
      if extensions.st_npoints(line)<3 or
        extensions.st_length(line::extensions.geography)<(cfg->>'minimum_route_distance')::double precision then continue;end if;
      if not extensions.st_isclosed(line) then line:=extensions.st_addpoint(line,extensions.st_startpoint(line));end if;
      if extensions.st_npoints(line)<4 or not extensions.st_issimple(line) then continue;end if;
      polygon:=extensions.st_makepolygon(line);
      if not extensions.st_isvalid(polygon) or
        extensions.st_area(polygon::extensions.geography)<(cfg->>'minimum_capture_area')::double precision or
        extensions.st_area(polygon::extensions.geography)>(cfg->>'maximum_capture_area')::double precision or
        not extensions.st_covers(extensions.st_makeenvelope(65.34,44.72,65.70,44.98,4326),polygon) then continue;end if;
      projected:=extensions.st_transform(polygon,32641);
      -- Existing manually blocked cells are never re-enabled by the generator.
      insert into public.territory_cells(hex_id,geometry,center_lat,center_lng,is_playable,area)
        select 'utm41-25-'||h.i||'-'||h.j,g.geom,
          extensions.st_y(extensions.st_centroid(g.geom)),extensions.st_x(extensions.st_centroid(g.geom)),
          true,extensions.st_area(g.geom::extensions.geography)
        from extensions.st_hexagongrid(25,projected) h
        cross join lateral (select extensions.st_transform(h.geom,4326) as geom) g
        where extensions.st_covers(projected,h.geom) and not exists(
          select 1 from public.territory_restrictions r where extensions.st_intersects(r.geometry,g.geom))
        order by 'utm41-25-'||h.i||'-'||h.j on conflict(hex_id) do nothing;
      update public.activity_sessions set capture_status='no_playable' where id=p_id;
      select count(*) into cell_count from public.territory_events where activity_id=p_id
        and event_type in ('capture','attack','defend');
      for cell in select c.* from public.territory_cells c where c.is_playable
        and extensions.st_covers(polygon,c.geometry)
        and not exists(select 1 from public.territory_restrictions r where extensions.st_intersects(r.geometry,c.geometry))
        and not exists(select 1 from public.territory_events e where e.activity_id=p_id and e.cell_id=c.id
          and e.event_type in ('capture','attack','defend'))
        order by c.hex_id for update loop
        if cell_count>=4000 then exit;end if;
        before_team:=cell.owner_team_id;before_user:=cell.owner_user_id;
        if cell.owner_team_id is null then
          event_kind:='capture';new_hp:=(cfg->>'default_cell_hp')::int;
        elsif cell.owner_team_id=s.team_id then
          select coalesce(sum(hp_after-hp_before),0) into defended_today from public.territory_events
            where cell_id=cell.id and event_type='defend'
              and (created_at at time zone 'Asia/Qyzylorda')::date=(now() at time zone 'Asia/Qyzylorda')::date;
          new_hp:=least(cell.max_hp,cell.hp+greatest(0,least((cfg->>'capture_defend_hp')::int,
            (cfg->>'daily_defend_limit')::int-defended_today)));
          if new_hp=cell.hp then continue;end if;
          event_kind:='defend';
        else
          new_hp:=greatest(0,cell.hp-(cfg->>'attack_damage')::int);
          event_kind:=case when new_hp=0 then 'capture' else 'attack' end;
          if new_hp=0 then new_hp:=(cfg->>'default_cell_hp')::int;end if;
        end if;
        new_hp:=least(cell.max_hp,new_hp);
        update public.territory_cells set hp=new_hp,last_activity_at=now(),
          owner_team_id=case when event_kind='capture' then s.team_id else owner_team_id end,
          owner_user_id=case when event_kind='capture' then s.user_id else owner_user_id end,
          captured_at=case when event_kind='capture' then now() else captured_at end where id=cell.id;
        insert into public.territory_events(cell_id,user_id,team_id,activity_id,event_type,
          previous_owner,new_owner,hp_before,hp_after) values(cell.id,s.user_id,s.team_id,p_id,event_kind,
          before_team,case when event_kind='capture' then s.team_id else before_team end,cell.hp,new_hp);
        if event_kind='capture' then gained:=gained+cell.area;end if;
        if before_user is not null then affected_users:=array_append(affected_users,before_user);end if;
        cell_count:=cell_count+1;changed:=true;
      end loop;
      exit; -- One qualifying contour per new endpoint; later loops are still processed.
    end loop;
  end loop;
  update public.activity_sessions set capture_processed_seq=last_seq,captured_area=captured_area+gained where id=p_id;
  if changed then
    -- Lock aggregate rows in a stable order; no client can write these columns.
    for affected in select distinct team from (
      select previous_owner as team from public.territory_events where activity_id=p_id
      union select new_owner from public.territory_events where activity_id=p_id
    ) t where team is not null order by team loop
      perform 1 from public.teams where id=affected.team for update;
      update public.teams set territory_area=(select coalesce(sum(area),0) from public.territory_cells
        where owner_team_id=affected.team) where id=affected.team;
    end loop;
    for affected in select distinct unnest(affected_users) as id order by id loop
      perform 1 from public.users where id=affected.id for update;
      update public.users set total_area=(select coalesce(sum(area),0) from public.territory_cells
        where owner_user_id=affected.id) where id=affected.id;
    end loop;
  end if;
  return public.activity_capture_result(p_id);
end;$$;

alter function public.append_activity_points(uuid,int,jsonb) rename to append_activity_points_validated;
alter function public.finish_activity(uuid,timestamptz,int) rename to finish_activity_validated;
revoke all on function public.append_activity_points_validated(uuid,int,jsonb),
  public.finish_activity_validated(uuid,timestamptz,int) from public,anon,authenticated;
create function public.append_activity_points(p_id uuid,p_offset int,p_points jsonb) returns jsonb
language plpgsql security definer set search_path='' as $$
begin
  if p_offset>20000 then raise exception 'Activity point limit';end if;
  perform public.append_activity_points_validated(p_id,p_offset,p_points);
  return public.process_activity_capture(p_id);
end;$$;
create function public.finish_activity(p_id uuid,p_ended_at timestamptz,p_reported_steps int default null) returns jsonb
language plpgsql security definer set search_path='' as $$
begin
  -- Validate finish before mutating cells. Any failure rolls back this transaction.
  perform public.finish_activity_validated(p_id,p_ended_at,p_reported_steps);
  return public.activity_capture_result(p_id);
end;$$;

create function public.get_territory_cells(p_west double precision,p_south double precision,
  p_east double precision,p_north double precision) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare bounds extensions.geometry;result jsonb;
begin
  if auth.uid() is null or not exists(select 1 from public.users where id=auth.uid() and not is_banned) then
    raise exception 'Authentication required';end if;
  if p_west is null or p_south is null or p_east is null or p_north is null or
    p_west not between -180 and 180 or p_east not between -180 and 180 or
    p_south not between -90 and 90 or p_north not between -90 and 90 or
    p_west>=p_east or p_south>=p_north then raise exception 'Invalid viewport';end if;
  bounds:=extensions.st_intersection(extensions.st_makeenvelope(p_west,p_south,p_east,p_north,4326),
    extensions.st_makeenvelope(65.34,44.72,65.70,44.98,4326));
  select jsonb_build_object('type','FeatureCollection','features',coalesce(jsonb_agg(feature),'[]'::jsonb))
    into result from (
      select jsonb_build_object('type','Feature','id',c.hex_id,
        'properties',jsonb_build_object('id',c.hex_id,'hp',c.hp,'area',c.area,
          'owner_team_id',c.owner_team_id,'color',t.primary_color),
        'geometry',extensions.st_asgeojson(c.geometry)::jsonb) as feature
      from public.territory_cells c join public.teams t on t.id=c.owner_team_id
      where extensions.st_intersects(c.geometry,bounds) order by c.hex_id limit 2000
    ) visible;
  return result;
end;$$;
revoke all on function public.activity_capture_result(uuid),public.process_activity_capture(uuid),
  public.append_activity_points(uuid,int,jsonb),public.finish_activity(uuid,timestamptz,int),
  public.get_territory_cells(double precision,double precision,double precision,double precision) from public,anon,authenticated;
grant execute on function public.append_activity_points(uuid,int,jsonb),
  public.finish_activity(uuid,timestamptz,int),
  public.get_territory_cells(double precision,double precision,double precision,double precision) to authenticated;

-- Team area updates signal viewport refresh without exposing private route data.
do $$ begin
  if exists(select 1 from pg_publication where pubname='supabase_realtime') and not exists(
    select 1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename='teams') then
    alter publication supabase_realtime add table public.teams;
  end if;
end;$$;
