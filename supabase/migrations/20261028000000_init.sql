-- Learn-It on Supabase (v0.2)
-- Security model: RLS on every table, column-level grants, no direct token access.

create extension if not exists citext   with schema extensions;
create extension if not exists pg_trgm  with schema extensions;
create extension if not exists pgcrypto with schema extensions;

create type public.set_visibility as enum ('private', 'link', 'public');

-- ---------- Profiles (1:1 with auth.users) ----------
create table public.profiles (
  id         uuid primary key references auth.users(id) on delete cascade,
  username   extensions.citext not null unique check (username ~ '^[A-Za-z0-9_]{3,30}$'),
  created_at timestamptz not null default now()
);

create function public.handle_new_user() returns trigger
language plpgsql security definer set search_path = public as $$
declare cand text; final text;
begin
  cand := regexp_replace(
    coalesce(new.raw_user_meta_data->>'username', new.raw_user_meta_data->>'user_name', ''),
    '[^A-Za-z0-9_]', '', 'g');
  if char_length(cand) between 3 and 30
     and not exists (select 1 from public.profiles where username = cand) then
    final := cand;
  else
    final := 'user_' || substr(replace(new.id::text, '-', ''), 1, 12);
  end if;
  insert into public.profiles (id, username) values (new.id, final);
  return new;
end $$;

create trigger on_auth_user_created after insert on auth.users
  for each row execute function public.handle_new_user();

-- ---------- Sets & cards ----------
create table public.study_sets (
  id          uuid primary key default gen_random_uuid(),
  owner_id    uuid not null references public.profiles(id) on delete cascade,
  title       text not null check (char_length(title) between 1 and 150),
  description text check (char_length(description) <= 2000),
  visibility  public.set_visibility not null default 'private',
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);
create index on public.study_sets (owner_id);
create index study_sets_title_trgm on public.study_sets
  using gin (title extensions.gin_trgm_ops) where visibility = 'public';

create function public.touch_updated_at() returns trigger language plpgsql as $$
begin new.updated_at := now(); return new; end $$;
create trigger study_sets_touch before update on public.study_sets
  for each row execute function public.touch_updated_at();

create table public.cards (
  id         uuid primary key default gen_random_uuid(),
  set_id     uuid not null references public.study_sets(id) on delete cascade,
  position   int  not null,
  term       text not null check (char_length(term) between 1 and 2000),
  definition text not null check (char_length(definition) between 1 and 4000),
  image_key  text,  -- reserved for Storage; not client-writable yet
  unique (set_id, position)
);
create index on public.cards (set_id);

-- Caps cards per set and auto-assigns position. Runs as the caller (RLS applies).
create function public.cards_before_insert() returns trigger
language plpgsql set search_path = public as $$
declare n int; mx int;
begin
  perform 1 from public.study_sets where id = new.set_id for update;
  select count(*), coalesce(max(position), 0) into n, mx from public.cards where set_id = new.set_id;
  if n >= 1000 then raise exception 'A set can have at most 1000 cards' using errcode = '54000'; end if;
  if new.position is null then new.position := mx + 1; end if;
  return new;
end $$;
create trigger cards_before_insert before insert on public.cards
  for each row execute function public.cards_before_insert();

-- ---------- Link sharing: only a hash of the token is stored, in a table clients cannot touch ----------
create table public.set_share_links (
  set_id     uuid primary key references public.study_sets(id) on delete cascade,
  token_hash bytea not null,
  created_at timestamptz not null default now()
);

create function public.drop_link_on_visibility_change() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if new.visibility <> 'link' then delete from public.set_share_links where set_id = new.id; end if;
  return new;
end $$;
create trigger study_sets_drop_link after update of visibility on public.study_sets
  for each row when (old.visibility is distinct from new.visibility)
  execute function public.drop_link_on_visibility_change();

-- Owner calls this after setting visibility = 'link'. The raw token is returned once; calling again rotates it.
create function public.create_share_link(p_set_id uuid) returns text
language plpgsql security definer set search_path = public, extensions as $$
declare tok text;
begin
  if auth.uid() is null then raise exception 'not authenticated' using errcode = '28000'; end if;
  if not exists (select 1 from public.study_sets
                 where id = p_set_id and owner_id = auth.uid() and visibility = 'link') then
    raise exception 'set not found or not link-shared' using errcode = 'P0002';
  end if;
  tok := translate(encode(gen_random_bytes(18), 'base64'), '+/', '-_');
  insert into public.set_share_links (set_id, token_hash) values (p_set_id, digest(tok, 'sha256'))
  on conflict (set_id) do update set token_hash = excluded.token_hash, created_at = now();
  return tok;
end $$;

-- Anyone holding a valid token can read that one set. Returns null otherwise (no existence leak).
create function public.get_set_by_link(p_set_id uuid, p_token text) returns jsonb
language plpgsql security definer stable set search_path = public, extensions as $$
begin
  if p_token is null or not exists (
    select 1 from public.set_share_links l join public.study_sets s on s.id = l.set_id
    where l.set_id = p_set_id and s.visibility = 'link' and l.token_hash = digest(p_token, 'sha256')
  ) then return null; end if;
  return (select jsonb_build_object(
    'id', s.id, 'title', s.title, 'description', s.description,
    'cards', coalesce((select jsonb_agg(jsonb_build_object(
        'id', c.id, 'position', c.position, 'term', c.term, 'definition', c.definition) order by c.position)
      from public.cards c where c.set_id = s.id), '[]'::jsonb))
    from public.study_sets s where s.id = p_set_id);
end $$;

-- ---------- Learning progress (SM-2) ----------
create table public.card_progress (
  user_id          uuid not null references public.profiles(id) on delete cascade,
  card_id          uuid not null references public.cards(id) on delete cascade,
  ease_factor      real not null default 2.5 check (ease_factor >= 1.3),
  interval_days    int  not null default 0,
  repetitions      int  not null default 0,
  due_at           timestamptz not null default now(),
  last_reviewed_at timestamptz,
  primary key (user_id, card_id)
);
create index on public.card_progress (user_id, due_at);

create table public.study_sessions (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null references public.profiles(id) on delete cascade,
  set_id     uuid not null references public.study_sets(id) on delete cascade,
  mode       text not null check (mode in ('flashcards','written','test','match')),
  score      int,
  started_at timestamptz not null default now(),
  ended_at   timestamptz
);
create index on public.study_sessions (user_id, started_at desc);

-- Quality 0-5 (SM-2). Clients cannot write card_progress directly, so progress can't be forged.
create function public.review_card(p_card_id uuid, p_quality int) returns public.card_progress
language plpgsql security definer set search_path = public as $$
declare
  uid uuid := auth.uid(); cur public.card_progress; res public.card_progress;
  ease real; reps int; ivl int;
begin
  if uid is null then raise exception 'not authenticated' using errcode = '28000'; end if;
  if p_quality is null or p_quality not between 0 and 5 then
    raise exception 'quality must be 0 to 5' using errcode = '22023';
  end if;
  if not exists (select 1 from public.cards c join public.study_sets s on s.id = c.set_id
                 where c.id = p_card_id and (s.owner_id = uid or s.visibility = 'public')) then
    raise exception 'card not found' using errcode = 'P0002';
  end if;
  select * into cur from public.card_progress where user_id = uid and card_id = p_card_id;
  ease := coalesce(cur.ease_factor, 2.5);
  reps := coalesce(cur.repetitions, 0);
  ivl  := coalesce(cur.interval_days, 0);
  if p_quality < 3 then
    reps := 0; ivl := 1;
  else
    reps := reps + 1;
    ivl := case when reps = 1 then 1 when reps = 2 then 6 else greatest(1, round(ivl * ease)::int) end;
    ease := greatest(1.3, ease + (0.1 - (5 - p_quality) * (0.08 + (5 - p_quality) * 0.02)));
  end if;
  insert into public.card_progress (user_id, card_id, ease_factor, interval_days, repetitions, due_at, last_reviewed_at)
  values (uid, p_card_id, ease, ivl, reps, now() + make_interval(days => ivl), now())
  on conflict (user_id, card_id) do update set
    ease_factor = excluded.ease_factor, interval_days = excluded.interval_days,
    repetitions = excluded.repetitions, due_at = excluded.due_at, last_reviewed_at = excluded.last_reviewed_at
  returning * into res;
  return res;
end $$;

-- ---------- GDPR: export and delete ----------
create function public.export_my_data() returns jsonb
language sql stable set search_path = public as $$
  select jsonb_build_object(
    'profile',  (select to_jsonb(p) from public.profiles p where p.id = auth.uid()),
    'sets',     (select coalesce(jsonb_agg(to_jsonb(s) || jsonb_build_object('cards',
                   (select coalesce(jsonb_agg(to_jsonb(c) order by c.position), '[]'::jsonb)
                    from public.cards c where c.set_id = s.id))), '[]'::jsonb)
                 from public.study_sets s where s.owner_id = auth.uid()),
    'progress', (select coalesce(jsonb_agg(to_jsonb(cp)), '[]'::jsonb) from public.card_progress cp where cp.user_id = auth.uid()),
    'sessions', (select coalesce(jsonb_agg(to_jsonb(ss)), '[]'::jsonb) from public.study_sessions ss where ss.user_id = auth.uid())
  );
$$;

create function public.delete_my_account() returns void
language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'not authenticated' using errcode = '28000'; end if;
  delete from auth.users where id = auth.uid();  -- cascades to profile, sets, cards, progress
end $$;

-- ---------- Row Level Security ----------
alter table public.profiles        enable row level security;
alter table public.study_sets      enable row level security;
alter table public.cards           enable row level security;
alter table public.card_progress   enable row level security;
alter table public.study_sessions  enable row level security;
alter table public.set_share_links enable row level security;  -- no policies: unreachable by clients

create policy profiles_select on public.profiles for select to anon, authenticated using (true);
create policy profiles_update_own on public.profiles for update to authenticated
  using (id = (select auth.uid())) with check (id = (select auth.uid()));

create policy sets_select on public.study_sets for select to anon, authenticated
  using (visibility = 'public' or owner_id = (select auth.uid()));
create policy sets_insert on public.study_sets for insert to authenticated
  with check (owner_id = (select auth.uid()));
create policy sets_update on public.study_sets for update to authenticated
  using (owner_id = (select auth.uid())) with check (owner_id = (select auth.uid()));
create policy sets_delete on public.study_sets for delete to authenticated
  using (owner_id = (select auth.uid()));

create policy cards_select on public.cards for select to anon, authenticated
  using (exists (select 1 from public.study_sets s where s.id = cards.set_id
                 and (s.visibility = 'public' or s.owner_id = (select auth.uid()))));
create policy cards_insert on public.cards for insert to authenticated
  with check (exists (select 1 from public.study_sets s where s.id = cards.set_id and s.owner_id = (select auth.uid())));
create policy cards_update on public.cards for update to authenticated
  using (exists (select 1 from public.study_sets s where s.id = cards.set_id and s.owner_id = (select auth.uid())))
  with check (exists (select 1 from public.study_sets s where s.id = cards.set_id and s.owner_id = (select auth.uid())));
create policy cards_delete on public.cards for delete to authenticated
  using (exists (select 1 from public.study_sets s where s.id = cards.set_id and s.owner_id = (select auth.uid())));

create policy progress_select on public.card_progress for select to authenticated using (user_id = (select auth.uid()));
create policy progress_delete on public.card_progress for delete to authenticated using (user_id = (select auth.uid()));

create policy sessions_select on public.study_sessions for select to authenticated using (user_id = (select auth.uid()));
create policy sessions_insert on public.study_sessions for insert to authenticated
  with check (user_id = (select auth.uid()) and exists (select 1 from public.study_sets s where s.id = set_id));

-- ---------- Grants (least privilege; RLS is the second lock) ----------
revoke all on public.profiles, public.study_sets, public.cards, public.card_progress,
              public.study_sessions, public.set_share_links from anon, authenticated;

grant select on public.profiles, public.study_sets, public.cards to anon, authenticated;
grant update (username) on public.profiles to authenticated;
grant insert (owner_id, title, description, visibility), update (title, description, visibility), delete
  on public.study_sets to authenticated;
grant insert (set_id, position, term, definition), update (position, term, definition), delete
  on public.cards to authenticated;
grant select, delete on public.card_progress to authenticated;
grant select, insert on public.study_sessions to authenticated;

revoke execute on function public.create_share_link(uuid), public.review_card(uuid, int),
  public.export_my_data(), public.delete_my_account(), public.get_set_by_link(uuid, text)
  from public, anon, authenticated;
grant execute on function public.get_set_by_link(uuid, text) to anon, authenticated;
grant execute on function public.create_share_link(uuid), public.review_card(uuid, int),
  public.export_my_data(), public.delete_my_account() to authenticated;
