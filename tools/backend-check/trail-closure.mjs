import assert from 'node:assert/strict';

// Keep these routes outside the earlier simulation so ownership is independent.
export async function checkTrailClosure(db, user, asUser) {
  let sequence = 0;
  const meters = 6371008.8 * Math.PI / 180;
  const longitudeMeters = meters * Math.cos(44.90 * Math.PI / 180);
  async function run(vertices, {split = -1, batched = false} = {}) {
    const start = new Date(Date.now() - 3600000);
    const points = vertices.map(([x, y], i) => ({
      latitude: 44.90 + y / meters, longitude: 65.55 + x / longitudeMeters,
      timestamp: new Date(+start + i * 30000 + (i >= split && split >= 0 ? 70000 : 0)).toISOString(),
      accuracy: 5, speed: 1.3, mocked: false,
    }));
    const id = `77777777-7777-4777-8777-${String(++sequence).padStart(12, '0')}`;
    await asUser(user);
    await db.query('select public.start_activity($1,$2)', [id, start.toISOString()]);
    if (batched) {
      const open = (await db.query('select public.append_activity_points($1,0,$2::jsonb) as r',
        [id, JSON.stringify(points.slice(0, -1))])).rows[0].r;
      assert.equal(open.territory.features.length, 0, 'approach must stay open');
    }
    const offset = batched ? points.length - 1 : 0;
    const batch = JSON.stringify(points.slice(offset));
    const result = (await db.query('select public.append_activity_points($1,$2,$3::jsonb) as r', [id, offset, batch])).rows[0].r;
    const retry = (await db.query('select public.append_activity_points($1,$2,$3::jsonb) as r', [id, offset, batch])).rows[0].r;
    assert.deepEqual(retry, result);
    const finished = (await db.query('select public.finish_activity($1,$2,289) as r', [id, points.at(-1).timestamp])).rows[0].r;
    assert.deepEqual(finished, result);
    return {id, result};
  }
  await db.exec('reset role');
  const config = (await db.query("select value from public.app_config where key='game'")).rows[0].value;
  assert.equal(config.minimum_route_distance, 100);
  const short = await run([[-30, -22.5], [30, -22.5], [30, 22.5], [-30, 22.5], [-30, -22.5]]);
  assert.ok(short.result.captured_area > 0, 'a 210 m loop must capture');
  const mid = [[-120, 0], [-60, 0], [60, 0], [60, 60], [0, 60], [0, 0]];
  const middle = await run(mid, {batched: true});
  assert.ok(middle.result.territory.features.length > 0, 'closure between distant old samples must capture');
  const crossing = mid.map(p => [...p]); crossing.at(-1)[1] = -35;
  const crossed = await run(crossing, {batched: true});
  assert.ok(crossed.result.territory.features.length > 0, 'crossing with a 35 m overshoot must capture');
  const near = mid.map(p => [...p]); near.at(-1)[1] = 5;
  const snapped = await run(near, {batched: true});
  assert.ok(snapped.result.territory.features.length > 0, 'GPS tolerance applies to a segment interior');
  for (const [name, vertices, options] of [
    ['open', mid.map((p, i) => i === mid.length - 1 ? [0, 30] : p), {}],
    ['gap', mid, {split: 3}],
    ['small area', [[0, 0], [80, 0], [80, 8], [0, 8], [0, 0]], {}],
    ['retracing', [[0, 0], [60, 0], [120, 0], [60, 0], [0, 0]], {}],
  ]) {
    const rejected = await run(vertices, options);
    assert.equal(rejected.result.territory.features.length, 0, name);
  }
  await asUser(user);
  const refreshed = (await db.query('select public.get_activity_capture($1) as r', [short.id])).rows[0].r;
  assert.deepEqual(refreshed, short.result);
  await assert.rejects(db.query('select public.get_activity_capture($1)', ['99999999-3333-4333-8333-333333333333']), /Activity unavailable/);
  await assert.rejects(db.query('select * from public.activity_trail_loops($1,0,5,25)', [middle.id]), /permission denied/);
  console.log('PASS 210 m capture, segment-interior closure, crossing/overshoot, GPS tolerance, batched closure and rejected open/gap/small/retraced routes');
}
