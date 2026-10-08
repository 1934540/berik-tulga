create schema if not exists extensions;
create extension if not exists postgis with schema extensions;

create table public.teams (
  id uuid primary key default gen_random_uuid(), name text not null,
  description text not null default '', logo text,
  primary_color text not null default '#FF673B', secondary_color text not null default '#11151A',
  total_steps bigint not null default 0, total_distance double precision not null default 0,
  territory_area double precision not null default 0, created_at timestamptz not null default now()
);
create table public.users (
  id uuid primary key references auth.users on delete cascade,
  username text unique check (username ~ '^[a-z0-9_]{3,24}$'), full_name text not null default '',
  avatar_url text, city text not null default 'Қызылорда', gender text, birth_date date,
  team_id uuid references public.teams,
  level int not null default 1, xp bigint not null default 0,
  current_streak int not null default 0, max_streak int not null default 0,
  total_steps bigint not null default 0, total_distance double precision not null default 0,
  total_area double precision not null default 0, is_banned boolean not null default false,
  created_at timestamptz not null default now(),
  check (char_length(full_name) <= 60), check (gender is null or gender in ('male','female'))
);
create table public.team_members (
  user_id uuid primary key references public.users on delete cascade,
  team_id uuid not null references public.teams, joined_at timestamptz not null default now()
);
create index team_members_team_idx on public.team_members(team_id);
create table public.activity_sessions (
  id uuid primary key, user_id uuid not null references public.users,
  team_id uuid not null references public.teams,
  started_at timestamptz not null, ended_at timestamptz,
  reported_steps int, steps int not null default 0, distance double precision not null default 0,
  duration int not null default 0, average_speed double precision not null default 0,
  max_speed double precision not null default 0, captured_area double precision not null default 0,
  status text not null default 'active' check (status in ('active','completed','blocked')),
  is_valid boolean not null default false, anti_cheat_score double precision not null default 0,
  created_at timestamptz not null default now()
);
create index activity_sessions_owner_idx on public.activity_sessions(user_id,started_at desc);
create table public.activity_points (
  activity_id uuid references public.activity_sessions on delete cascade,
  seq int not null check(seq >= 0), latitude double precision not null check(latitude between -90 and 90),
  longitude double precision not null check(longitude between -180 and 180),
  timestamp timestamptz not null, accuracy double precision not null check(accuracy >= 0),
  speed double precision not null default 0, altitude double precision,
  mocked boolean not null default false, accepted boolean not null default false,
  segment_start boolean not null default true,
  primary key(activity_id,seq)
);
create table public.territory_cells (
  id uuid primary key default gen_random_uuid(), hex_id text unique not null,
  geometry extensions.geometry(Polygon,4326) not null,
  center_lat double precision not null, center_lng double precision not null,
  owner_team_id uuid references public.teams, owner_user_id uuid references public.users,
  hp int not null default 0, max_hp int not null default 300,
  is_playable boolean not null default false,
  captured_at timestamptz, last_activity_at timestamptz,
  check(hp >= 0 and hp <= max_hp)
);
create index territory_cells_geometry_idx on public.territory_cells using gist(geometry);
create table public.territory_events (
  id uuid primary key default gen_random_uuid(), cell_id uuid references public.territory_cells,
  user_id uuid references public.users, team_id uuid references public.teams,
  activity_id uuid references public.activity_sessions,
  event_type text not null check(event_type in ('capture','attack','defend','decay','neutralize')),
  previous_owner uuid references public.teams,new_owner uuid references public.teams,
  hp_before int not null,hp_after int not null,created_at timestamptz not null default now()
);
create table public.daily_stats (
  user_id uuid references public.users,date date not null,steps bigint not null default 0,
  distance double precision not null default 0,area double precision not null default 0,
  xp bigint not null default 0,primary key(user_id,date)
);
create table public.leaderboard_scores (
  subject_id uuid not null,display_name text not null,color bigint not null default 4294928187,
  kind text not null check(kind in ('user','team')),
  period text not null check(period in ('today','week','month')),
  period_start date not null,metric text not null check(metric in ('steps','distance','area','xp')),
  score double precision not null default 0,primary key(subject_id,kind,period,period_start,metric)
);
create view public.leaderboards with (security_invoker=true) as
  select * from public.leaderboard_scores
  where period_start = case period
    when 'today' then (now() at time zone 'Asia/Qyzylorda')::date
    when 'week' then date_trunc('week',now() at time zone 'Asia/Qyzylorda')::date
    when 'month' then date_trunc('month',now() at time zone 'Asia/Qyzylorda')::date end;
create table public.achievements (
  id text primary key,title_key text not null,threshold bigint not null,metric text not null
);
create table public.user_achievements (
  user_id uuid references public.users,achievement_id text references public.achievements,
  unlocked_at timestamptz not null default now(),primary key(user_id,achievement_id)
);
create table public.seasons (
  id uuid primary key default gen_random_uuid(),name text not null,
  starts_at timestamptz not null,ends_at timestamptz not null,is_active boolean not null default false,
  check(ends_at > starts_at)
);
create unique index single_active_season on public.seasons(is_active) where is_active;
create table public.season_scores (
  season_id uuid references public.seasons,team_id uuid references public.teams,
  steps bigint not null default 0,distance double precision not null default 0,
  territory double precision not null default 0,team_score bigint not null default 0,
  primary key(season_id,team_id)
);
create table public.app_config (key text primary key,value jsonb not null);
insert into public.app_config values ('game','{
  "hex_size":25,"closure_distance":25,"minimum_route_distance":300,"minimum_capture_area":1000,
  "default_cell_hp":100,"max_cell_hp":300,"attack_damage":20,"defend_hp":10,
  "capture_defend_hp":20,"daily_defend_limit":50,"territory_decay_days":7,"territory_decay_hp":10,
  "max_walking_speed":12,"max_capture_speed":20,"max_gps_accuracy":50,"privacy_radius":200,
  "territory_enabled":false,"xp_enabled":false,
  "levels":[0,500,1200,2500],"morning_bonuses":[[5,6,3],[6,7,2],[7,9,1.5]]
}');
insert into public.teams(id,name,description) values
 ('00000000-0000-4000-8000-000000000001','Берік Тұлға','Қадам бас. Аумақты иелен. Өзіңді жең.');
insert into public.achievements values
 ('steps_1000','first1000',1000,'steps'),('distance_5000','first5k',5000,'distance'),
 ('first_capture','firstCapture',1,'capture'),('area_10000','area10k',10000,'area'),
 ('area_100000','area100k',100000,'area'),('streak_7','sevenDays',7,'streak'),
 ('streak_30','thirtyDays',30,'streak'),('weekly_first','weeklyWinner',1,'weekly_rank');

create function public.on_auth_user_created() returns trigger
language plpgsql security definer set search_path='' as $$
begin insert into public.users(id) values(new.id);return new;end;
$$;
create trigger auth_user_created after insert on auth.users
for each row execute function public.on_auth_user_created();
revoke all on function public.on_auth_user_created() from public;
