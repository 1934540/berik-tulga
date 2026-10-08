import assert from 'node:assert/strict';

export async function checkTerritoryRules(db,a,b,asUser) {
  const corners=[[44.8491,65.4804],[44.8506,65.4812],[44.8515,65.4854],
    [44.8496,65.4865],[44.8474,65.4855],[44.8471,65.4826],[44.8491,65.4804]];
  const polygon=`POLYGON((${corners.map(([lat,lng])=>`${lng} ${lat}`).join(',')}))`;
  let sequence=0;
  function route(vertices=corners) {
    const start=new Date(Date.now()-3600000),points=[];
    for(let i=0;i<vertices.length-1;i++)for(let j=0;j<12;j++) points.push({
      latitude:vertices[i][0]+(vertices[i+1][0]-vertices[i][0])*j/12,
      longitude:vertices[i][1]+(vertices[i+1][1]-vertices[i][1])*j/12,
      timestamp:new Date(+start+(points.length+1)*20000).toISOString(),
      accuracy:5,speed:1.3,mocked:false,accepted:true,
      captured_area:99999999,owner_team_id:'forged',hp:999999});
    points.push({...points[0],timestamp:new Date(+start+(points.length+1)*20000).toISOString()});
    return {start,points};
  }
  async function run(data=route(),actor=a) {
    const id=`66666666-6666-4666-8666-${String(++sequence).padStart(12,'0')}`;
    await asUser(actor);
    await db.query('select public.start_activity($1,$2)',[id,data.start.toISOString()]);
    const appended=(await db.query('select public.append_activity_points($1,0,$2::jsonb) as r',[id,JSON.stringify(data.points)])).rows[0].r;
    const retry=(await db.query('select public.append_activity_points($1,0,$2::jsonb) as r',[id,JSON.stringify(data.points)])).rows[0].r;
    assert.deepEqual(retry,appended);
    const end=data.points.at(-1).timestamp;
    const finished=(await db.query('select public.finish_activity($1,$2,1872) as r',[id,end])).rows[0].r;
    assert.deepEqual(finished,appended);
    return {id,...finished};
  }
  await db.exec('reset role');
  const cells=(await db.query('select count(*)::int as n from public.territory_cells where owner_user_id=$1',[a])).rows[0].n;
  const open=route();open.points=open.points.slice(0,-5);
  const noisy=route();noisy.points[35].accuracy=90;
  const mock=route();mock.points[35].mocked=true;
  const gap=route();gap.points.forEach((p,i)=>{if(i>=35)p.timestamp=new Date(Date.parse(p.timestamp)+70000).toISOString();});
  const thin=route([[44.8491,65.4804],[44.8491,65.488],[44.849109,65.488],[44.849109,65.4804],[44.8491,65.4804]]);
  const outside=route(corners.map(([lat,lng])=>[lat+1,lng]));
  for(const [name,data] of [['open',open],['accuracy break',noisy],['mock break',mock],['GPS gap',gap],['small area',thin],['outside',outside]]) {
    const rejected=await run(data);
    assert.equal(rejected.captured_area,0,name);
    assert.equal(rejected.territory.features.length,0,name);
  }
  console.log('PASS open/small/out-of-region routes and GPS accuracy/mock/gaps do not capture or defend');
  await db.exec('reset role');
  await db.exec("update public.app_config set value=jsonb_set(value,'{territory_enabled}','false') where key='game'");
  const disabled=await run();assert.equal(disabled.capture_status,'disabled');
  assert.equal(disabled.territory.features.length,0);
  await db.exec('reset role');
  await db.exec("update public.app_config set value=jsonb_set(value,'{territory_enabled}','true') where key='game'");
  await db.exec('update public.territory_cells set is_playable=false');
  const unplayable=await run();assert.equal(unplayable.territory.features.length,0);
  await db.exec('reset role');await db.exec('update public.territory_cells set is_playable=true');
  await db.query("insert into public.territory_restrictions values('test-block','test',extensions.st_geomfromtext($1,4326))",[polygon]);
  const masked=await run();assert.equal(masked.territory.features.length,0);
  await db.exec('reset role');await db.exec("delete from public.territory_restrictions where id='test-block'");
  console.log('PASS disabled capture, manually blocked cells and exclusion masks');
  for(let i=0;i<3;i++) {
    const defended=await run();assert.equal(defended.captured_area,0);
    assert.equal(defended.defended_cells,cells);
    assert.ok(defended.territory.features.every(f=>f.properties.hp===Math.min(150,120+i*20)));
  }
  const capped=await run();assert.equal(capped.territory.features.length,0);
  console.log('PASS defense +20 HP, daily +50 HP cap, idempotent uploads, no repeated area');
  await db.exec('reset role');
  const enemyTeam='55555555-5555-4555-8555-555555555555';
  await db.query("insert into public.teams(id,name,primary_color) values($1,'Other team','#6CB8F4')",[enemyTeam]);
  await db.query('update public.users set team_id=$1 where id=$2',[enemyTeam,b]);
  await db.query('insert into public.team_members(user_id,team_id) values($1,$2)',[b,enemyTeam]);
  const target=(await db.query('select hex_id from public.territory_cells where owner_user_id=$1 order by hex_id limit 1',[a])).rows[0].hex_id;
  await db.query('update public.territory_cells set hp=20 where hex_id=$1',[target]);
  const attacked=await run(route(),b);
  assert.equal(attacked.attacked_cells,cells-1);
  assert.equal(attacked.capture_status,'captured');
  assert.equal(attacked.territory.features.find(f=>f.id===target).properties.owner_team_id,enemyTeam);
  assert.ok(attacked.territory.features.filter(f=>f.id!==target).every(f=>f.properties.hp===130));
  await db.exec('reset role');
  const enemyArea=(await db.query('select territory_area from public.teams where id=$1',[enemyTeam])).rows[0].territory_area;
  assert.ok(Math.abs(enemyArea-attacked.captured_area)<1e-6);
  console.log('PASS enemy attack -20 HP, capture at zero, owner/HP/team aggregates updated');
  await asUser(a);
  await assert.rejects(db.exec('update public.territory_cells set hp=300'),/permission denied/);
  await assert.rejects(db.query('select public.process_activity_capture($1)',[attacked.id]),/permission denied/);
  await assert.rejects(db.query('select public.append_activity_points_validated($1,0,$2::jsonb)',[attacked.id,'[]']),/permission denied/);
  const viewport=(await db.exec('select public.get_territory_cells(65.47,44.84,65.49,44.86) as data'))[0].rows[0].data;
  assert.ok(viewport.features.length>=cells);
  assert.ok(viewport.features.every(f=>!('owner_user_id' in f.properties)));
  await assert.rejects(db.exec('select public.get_territory_cells(70,50,65,40)'),/Invalid viewport/);
  console.log('PASS capture internals protected; forged metadata ignored; viewport bounds and privacy');
}
