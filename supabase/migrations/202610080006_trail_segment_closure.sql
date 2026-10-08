-- A short real walk can enclose enough area. Closure is measured to the trail,
-- including the interior of its segments and crossings between GPS samples.
update public.app_config set value=jsonb_set(value,'{minimum_route_distance}','100')
  where key='game';

create function public.activity_trail_loops(p_id uuid,p_first int,p_end int,p_tolerance double precision)
returns table(path extensions.geometry)
language plpgsql stable set search_path='' as $$
declare edge record;last_edge extensions.geometry;endpoint extensions.geometry;
  crossing extensions.geometry;anchor extensions.geometry;finish extensions.geometry;
begin
  select extensions.st_makeline(extensions.st_transform(
    extensions.st_setsrid(extensions.st_makepoint(longitude,latitude),4326),32641) order by seq)
    into last_edge from public.activity_points
    where activity_id=p_id and seq between p_end-1 and p_end and accepted;
  if last_edge is null or extensions.st_npoints(last_edge)<2 then return;end if;
  endpoint:=extensions.st_endpoint(last_edge);
  for edge in
    with samples as (
      select seq,extensions.st_transform(extensions.st_setsrid(
        extensions.st_makepoint(longitude,latitude),4326),32641) as geom
      from public.activity_points where activity_id=p_id and seq between p_first and p_end-1 and accepted
    ), edges as (
      select seq,extensions.st_makeline(geom,lead(geom) over(order by seq)) as geom from samples
    ) select * from edges where seq<=p_end-2 and geom is not null
      and extensions.st_length(geom)>.1
      and (extensions.st_dwithin(geom,endpoint,p_tolerance) or extensions.st_intersects(geom,last_edge))
      order by seq
  loop
    anchor:=extensions.st_closestpoint(edge.geom,endpoint);finish:=endpoint;
    crossing:=extensions.st_intersection(edge.geom,last_edge);
    if not extensions.st_isempty(crossing) and extensions.st_geometrytype(crossing)='ST_Point'
      and extensions.st_linelocatepoint(last_edge,crossing)>0 then
      anchor:=crossing;finish:=crossing;
    end if;
    if extensions.st_distance(anchor,finish)>p_tolerance then continue;end if;
    -- Prepend the point on the old edge, then trim any overshoot at the crossing.
    select extensions.st_makeline(geom order by n) into path from (
      select edge.seq::double precision as n,anchor as geom
      union all select seq::double precision,extensions.st_transform(extensions.st_setsrid(
        extensions.st_makepoint(longitude,latitude),4326),32641)
        from public.activity_points where activity_id=p_id and seq between edge.seq+1 and p_end-1
      union all select p_end::double precision,finish
    ) vertices;
    path:=extensions.st_transform(extensions.st_removerepeatedpoints(path,.001),4326);
    return next;
  end loop;
end;$$;
revoke all on function public.activity_trail_loops(uuid,int,int,double precision) from public,anon,authenticated;

-- Completed walks can receive a repaired result without replaying their GPS data.
create function public.get_activity_capture(p_id uuid) returns jsonb
language plpgsql stable security definer set search_path='' as $$
begin
  if not exists(select 1 from public.activity_sessions s join public.users u on u.id=s.user_id
    where s.id=p_id and s.user_id=auth.uid() and s.status<>'blocked' and not u.is_banned) then
    raise exception 'Activity unavailable';
  end if;
  return public.activity_capture_result(p_id);
end;$$;
revoke all on function public.get_activity_capture(uuid) from public,anon,authenticated;
grant execute on function public.get_activity_capture(uuid) to authenticated;

create or replace function public.process_activity_capture(p_id uuid) returns jsonb
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
    for anchor in select path from public.activity_trail_loops(p_id,segment_first,endpoint.seq,
      (cfg->>'closure_distance')::double precision) loop
      line:=anchor.path;
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
        where extensions.st_covers(projected,extensions.st_centroid(h.geom)) and not exists(
          select 1 from public.territory_restrictions r where extensions.st_intersects(r.geometry,g.geom))
        order by 'utm41-25-'||h.i||'-'||h.j on conflict(hex_id) do nothing;
      update public.activity_sessions set capture_status='no_playable' where id=p_id;
      select count(*) into cell_count from public.territory_events where activity_id=p_id
        and event_type in ('capture','attack','defend');
      for cell in select c.* from public.territory_cells c where c.is_playable
        and extensions.st_covers(polygon,extensions.st_setsrid(
          extensions.st_makepoint(c.center_lng,c.center_lat),4326))
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
