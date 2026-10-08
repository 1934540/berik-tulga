import { PGlite } from '@electric-sql/pglite';
import { postgis } from '@electric-sql/pglite-postgis';
import { readFile, readdir } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import { resolve, dirname } from 'node:path';
import assert from 'node:assert/strict';
import { checkTerritorySimulation } from './territory-simulation.mjs';
import { checkTerritoryRules } from './territory-rules.mjs';
import { checkTrailClosure } from './trail-closure.mjs';

// Supabase platform schemas are reproduced only for local RPC/RLS verification.
// This harness never connects to a cloud project or uses production credentials.
const db = new PGlite({ extensions: { postgis } });
await db.exec(`
  create role anon; create role authenticated;
  create schema auth; create schema storage;
  create table auth.users(id uuid primary key);
  create function auth.uid() returns uuid language sql stable as
    $$ select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid $$;
  create table storage.buckets(id text primary key,name text,public boolean,file_size_limit bigint,allowed_mime_types text[]);
  create table storage.objects(id uuid primary key default gen_random_uuid(),bucket_id text,name text);
  alter table storage.objects enable row level security;
  create function storage.foldername(name text) returns text[] language sql immutable as
    $$ select (string_to_array(name,'/'))[1:array_length(string_to_array(name,'/'),1)-1] $$;
  grant usage on schema public,auth,storage to anon,authenticated;
  grant select,insert,update on storage.objects to authenticated;
`);
const root = resolve(dirname(fileURLToPath(import.meta.url)), '../..');
const directory = resolve(root, 'supabase/migrations');
for (const name of (await readdir(directory)).filter(n => n.endsWith('.sql')).sort()) {
  await db.exec(await readFile(resolve(directory, name), 'utf8'));
  console.log(`PASS migration ${name}`);
}
await db.exec('grant usage on schema extensions to authenticated');
const a='11111111-1111-4111-8111-111111111111';
const b='22222222-2222-4222-8222-222222222222';
const id='33333333-3333-4333-8333-333333333333';
await db.query('insert into auth.users values($1),($2)',[a,b]);
async function as(user) {
  await db.exec('reset role');
  await db.query("select set_config('request.jwt.claim.sub',$1,false)",[user]);
  await db.exec('set role authenticated');
}
await as(a);
await db.query("update public.users set full_name='Aid',username='aid' where id=$1",[a]);
await db.exec('select public.join_default_team();select public.join_default_team()');
assert.equal((await db.exec('select * from public.my_team_summary()'))[0].rows[0].members_count,1);
console.log('PASS profile creation and idempotent team membership');
await assert.rejects(db.exec('update public.users set xp=9999'), /permission denied/);
await assert.rejects(db.exec('update public.teams set territory_area=9999'), /permission denied/);
await assert.rejects(db.exec('insert into public.activity_sessions(id) values(gen_random_uuid())'), /permission denied/);
assert.equal((await db.query('select * from public.users where id=$1',[b])).rows.length,0);
console.log('PASS protected gameplay columns and private profiles');
await db.query("insert into storage.objects(bucket_id,name) values('avatars',$1)",[`${a}/avatar.jpg`]);
await assert.rejects(db.query("insert into storage.objects(bucket_id,name) values('avatars',$1)",[`${b}/avatar.jpg`]),/row-level security/);
console.log('PASS avatar path ownership');
const start=new Date(Date.now()-600000);
await db.query('select public.start_activity($1,$2)',[id,start.toISOString()]);
const point=(longitude,seconds,accuracy=5,mocked=false)=>({latitude:44.8488,longitude,accuracy,speed:1.3,altitude:0,mocked,timestamp:new Date(+start+seconds*1000).toISOString(),accepted:true,segment_start:false});
const points=[point(65.4823,0),point(65.4824,10),point(65.5,15),point(65.5001,25),point(65.48,180),point(65.4801,190,70),point(65.4802,200,5,true)];
await db.query('select public.append_activity_points($1,0,$2::jsonb)',[id,JSON.stringify(points)]);
await db.query('select public.append_activity_points($1,0,$2::jsonb)',[id,JSON.stringify(points)]);
const stored=(await db.query('select * from public.activity_points where activity_id=$1 order by seq',[id])).rows;
assert.equal(stored.length,7);assert.equal(stored[2].accepted,false);assert.equal(stored[3].segment_start,true);
assert.equal(stored[4].segment_start,true);assert.equal(stored[5].accepted,false);assert.equal(stored[6].accepted,false);
await db.query('select public.finish_activity($1,$2,60000)',[id,new Date(+start+240000).toISOString()]);
await db.query('select public.finish_activity($1,$2,100000)',[id,new Date(+start+240000).toISOString()]);
const activity=(await db.query('select * from public.activity_sessions where id=$1',[id])).rows[0];
assert.ok(activity.distance>7 && activity.distance<9);assert.equal(activity.steps,0);
assert.equal(activity.reported_steps,60000);assert.equal(activity.captured_area,0);assert.equal(activity.duration,240);
console.log('PASS server GPS filtering, metric distance, idempotent batches and no unverified rewards');
await checkTerritorySimulation(db, a, as);
await checkTerritoryRules(db, a, b, as);
await checkTrailClosure(db, a, as);
await as(b);
assert.equal((await db.query('select * from public.activity_points where activity_id=$1',[id])).rows.length,0);
await assert.rejects(db.query('select public.finish_activity($1,now(),0)',[id]),/Activity unavailable/);
await assert.rejects(db.query('select public.append_activity_points($1,0,$2::jsonb)',[id,'[]']),/Activity unavailable/);
console.log('PASS private route access and RPC ownership checks');
await db.exec('reset role');
await db.close();
console.log('All backend checks passed.');
