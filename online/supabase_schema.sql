create table if not exists public.players (
  id uuid primary key default gen_random_uuid(),
  username text not null,
  username_key text not null unique,
  created_at timestamptz not null default now()
);

create table if not exists public.player_scores (
  player_id uuid primary key references public.players(id) on delete cascade,
  best_score integer not null default 0 check (best_score >= 0),
  kills integer not null default 0 check (kills >= 0),
  zones integer not null default 0 check (zones between 0 and 5),
  endless_seconds integer not null default 0 check (endless_seconds >= 0),
  updated_at timestamptz not null default now()
);

alter table public.players enable row level security;
alter table public.player_scores enable row level security;
revoke all on public.players from anon, authenticated;
revoke all on public.player_scores from anon, authenticated;

create or replace function public.register_player(p_username text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  cleaned text := btrim(p_username);
  normalized text;
  found public.players%rowtype;
begin
  if char_length(cleaned) < 3 or char_length(cleaned) > 20 then
    raise exception 'Username must contain between 3 and 20 characters';
  end if;
  if cleaned !~ '^[[:alnum:]_ -]+$' then
    raise exception 'Username contains unsupported characters';
  end if;
  normalized := lower(regexp_replace(cleaned, '[[:space:]]+', ' ', 'g'));
  insert into public.players (username, username_key)
  values (cleaned, normalized)
  on conflict (username_key) do update set username_key = excluded.username_key
  returning * into found;
  return jsonb_build_object('player_id', found.id, 'username', found.username);
end;
$$;

create or replace function public.submit_score(
  p_player_id uuid,
  p_score integer,
  p_kills integer,
  p_zones integer,
  p_endless_seconds integer
)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not exists (select 1 from public.players where id = p_player_id) then
    raise exception 'Unknown player';
  end if;
  insert into public.player_scores (player_id, best_score, kills, zones, endless_seconds)
  values (
    p_player_id,
    least(greatest(p_score, 0), 100000000),
    least(greatest(p_kills, 0), 1000000),
    least(greatest(p_zones, 0), 5),
    least(greatest(p_endless_seconds, 0), 10000000)
  )
  on conflict (player_id) do update
    set best_score = excluded.best_score,
        kills = excluded.kills,
        zones = excluded.zones,
        endless_seconds = excluded.endless_seconds,
        updated_at = now()
    where excluded.best_score > public.player_scores.best_score;
  return true;
end;
$$;

create or replace function public.get_global_leaderboard()
returns table (
  rank bigint,
  username text,
  best_score integer,
  kills integer,
  zones integer,
  endless_seconds integer
)
language sql
stable
security definer
set search_path = ''
as $$
  select
    row_number() over (order by scores.best_score desc, scores.updated_at asc) as rank,
    players.username,
    scores.best_score,
    scores.kills,
    scores.zones,
    scores.endless_seconds
  from public.player_scores as scores
  join public.players as players on players.id = scores.player_id
  order by scores.best_score desc, scores.updated_at asc
  limit 50;
$$;

revoke execute on function public.register_player(text) from public;
revoke execute on function public.submit_score(uuid, integer, integer, integer, integer) from public;
revoke execute on function public.get_global_leaderboard() from public;
grant execute on function public.register_player(text) to anon, authenticated;
grant execute on function public.submit_score(uuid, integer, integer, integer, integer) to anon, authenticated;
grant execute on function public.get_global_leaderboard() to anon, authenticated;
