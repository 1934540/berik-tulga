import assert from 'node:assert/strict';

// Uses an isolated local database and the real activity RPCs. The route follows
// the demo's six edges, with an extra final point to close the contour exactly.
export async function checkTerritorySimulation(db, user, asUser) {
  const id = '44444444-4444-4444-8444-444444444444';
  const start = new Date(Date.now() - 30 * 60 * 1000);
  const corners = [
    [44.8491, 65.4804], [44.8506, 65.4812], [44.8515, 65.4854],
    [44.8496, 65.4865], [44.8474, 65.4855], [44.8471, 65.4826],
    [44.8491, 65.4804],
  ];
  const points = [];
  for (let i = 0; i < corners.length - 1; i++) {
    for (let j = 0; j < 12; j++) {
      points.push({
        latitude: corners[i][0] + (corners[i + 1][0] - corners[i][0]) * j / 12,
        longitude: corners[i][1] + (corners[i + 1][1] - corners[i][1]) * j / 12,
        timestamp: new Date(+start + (points.length + 1) * 20000).toISOString(),
        accuracy: 5, speed: 1.3, mocked: false,
      });
    }
  }
  points.push({ ...points[0], timestamp: new Date(+start + 73 * 20000).toISOString() });
  const polygon = `POLYGON((${corners.map(([lat, lng]) => `${lng} ${lat}`).join(',')}))`;
  await db.exec('reset role');
  const config = (await db.query("select value from public.app_config where key='game'")).rows[0].value;
  assert.equal(config.territory_enabled, true);
  // Deliberately provide playable cells inside the loop so a missing region/grid
  // cannot explain a zero capture result.
  await db.query(`
    with region as (
      select extensions.st_transform(extensions.st_geomfromtext($1,4326),32641) as geom
    ), cells as (
      select h.geom,h.i,h.j from region,
        lateral extensions.st_hexagongrid(25,region.geom) h
      where extensions.st_contains(region.geom,h.geom) limit 3
    ), geographic as (
      select extensions.st_transform(geom,4326) as geom,i,j from cells
    )
    insert into public.territory_cells(hex_id,geometry,center_lat,center_lng,is_playable,area)
    select 'utm41-25-'||i||'-'||j,geom,
      extensions.st_y(extensions.st_centroid(geom)),
      extensions.st_x(extensions.st_centroid(geom)),true,
      extensions.st_area(geom::extensions.geography) from geographic
  `, [polygon]);
  const snapshot = async () => (await db.query(`
    select hex_id,owner_team_id,owner_user_id,hp,captured_at,last_activity_at
    from public.territory_cells where hex_id like 'utm41-25-%' order by hex_id
  `)).rows;
  const before = await snapshot();
  assert.equal(before.length, 3);
  const stats = async () => (await db.query(`
    select u.xp,u.total_area,t.territory_area from public.users u
    join public.teams t on t.id=u.team_id where u.id=$1
  `, [user])).rows[0];
  const statsBefore = await stats();
  const eventsBefore = (await db.query('select count(*)::int as n from public.territory_events')).rows[0].n;
  await asUser(user);
  await db.query('select public.start_activity($1,$2)', [id, start.toISOString()]);
  await db.query('select public.append_activity_points($1,0,$2::jsonb)', [id, JSON.stringify(points)]);
  const stored = (await db.query('select * from public.activity_points where activity_id=$1 order by seq', [id])).rows;
  assert.equal(stored.length, 73);
  assert.ok(stored.every(p => p.accepted));
  assert.equal(stored.filter(p => p.segment_start).length, 1);
  const geometry = (await db.query(`
    with route as (
      select extensions.st_makeline(
        extensions.st_setsrid(extensions.st_makepoint(longitude,latitude),4326)
        order by seq) as geom from public.activity_points where activity_id=$1
    ) select extensions.st_isclosed(geom) as closed,
      extensions.st_isvalid(extensions.st_makepolygon(geom)) as valid,
      extensions.st_area(extensions.st_makepolygon(geom)::extensions.geography) as area
    from route
  `, [id])).rows[0];
  assert.equal(geometry.closed, true);
  assert.equal(geometry.valid, true);
  assert.ok(geometry.area >= config.minimum_capture_area);
  const end = points.at(-1).timestamp;
  await db.query('select public.finish_activity($1,$2,$3)', [id, end, 1872]);
  const first = (await db.query('select public.finish_activity($1,$2,$3) as result', [id, end, 1872])).rows[0].result;
  // Repeated finish must leave ownership and rewards unchanged.
  await db.query('select public.finish_activity($1,$2,$3)', [id, end, 1872]);
  const activity = (await db.query('select * from public.activity_sessions where id=$1', [id])).rows[0];
  assert.equal(activity.status, 'completed');
  assert.equal(activity.is_valid, true);
  assert.ok(activity.distance >= config.minimum_route_distance);
  assert.equal(activity.anti_cheat_score, 0);
  assert.ok(activity.captured_area > 1000);
  assert.ok(first.territory.features.length > 3);
  assert.equal(first.capture_status, 'captured');
  await db.exec('reset role');
  const after = await snapshot();
  assert.ok(after.every(c => c.owner_user_id === user && c.hp === 100));
  const statsAfter = await stats();
  assert.equal(statsAfter.xp, statsBefore.xp);
  assert.ok(Math.abs(statsAfter.total_area - activity.captured_area) < 1e-6);
  assert.ok(Math.abs(statsAfter.territory_area - activity.captured_area) < 1e-6);
  assert.equal((await db.query('select count(*)::int as n from public.territory_events')).rows[0].n - eventsBefore, after.length);
  console.log(`PASS closed-loop territory simulation: ${stored.length} valid GPS points, ` +
    `${activity.distance.toFixed(2)} m route, ${geometry.area.toFixed(2)} m² enclosed, ` +
    `${after.length} captured cells, ${activity.captured_area.toFixed(2)} m² captured; owner/HP/events/team/profile updated, XP unchanged`);
}
