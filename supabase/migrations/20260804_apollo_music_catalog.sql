-- Apollo Cloud: the music catalog.
--
-- Until now a "song" was a Scrolls post whose caption carried its metadata in
-- tagged lines, with the track list base64'd inside. That was enough to publish
-- from the DAW, but it cannot be queried, sorted, searched, credited or counted,
-- so it cannot back a streaming service.
--
-- These tables make music first-class. Scrolls stays in the picture as a place a
-- release can be SHARED to, rather than the place it lives.
--
--   music_artists        an artist identity, owned by a user
--   music_releases       an album / EP / single, draft until published
--   music_tracks         a song within a release
--   music_track_assets   the files for a track (master, waveform, stems)
--   music_likes          a listener liking a track or release
--   music_library_items  saved releases and playlists
--   music_play_events    playback for counts and royalties
--
-- Media follows the existing provider/bucket/object_key convention so the DAW's
-- upload path and the CDN resolver keep working unchanged.

--------------------------------------------------------------------------------
-- Artists
--------------------------------------------------------------------------------
create table if not exists public.music_artists (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references public.users(id) on delete cascade,
  -- Lowercased for the /artist/[handle] route; uniqueness is enforced on it.
  handle text not null,
  display_name text not null,
  bio text,
  avatar_provider text,
  avatar_bucket text,
  avatar_object_key text,
  banner_provider text,
  banner_bucket text,
  banner_object_key text,
  verified boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint music_artists_handle_shape check (handle ~ '^[a-z0-9_.-]{2,32}$'),
  constraint music_artists_display_name_length check (
    char_length(trim(display_name)) between 1 and 80
  )
);

create unique index if not exists music_artists_handle_key
  on public.music_artists (handle);
-- One artist identity per user for now; collaborations are modelled as credits.
create unique index if not exists music_artists_owner_key
  on public.music_artists (owner_id);

--------------------------------------------------------------------------------
-- Releases
--------------------------------------------------------------------------------
create table if not exists public.music_releases (
  id uuid primary key default gen_random_uuid(),
  artist_id uuid not null references public.music_artists(id) on delete cascade,
  owner_id uuid not null references public.users(id) on delete cascade,
  title text not null,
  -- 'single' covers one-track releases; 'ep' and 'album' are editorial.
  release_type text not null default 'single'
    check (release_type in ('single', 'ep', 'album')),
  -- A release may be held as a draft for Studio review or published directly
  -- by the DAW.
  status text not null default 'draft'
    check (status in ('draft', 'published', 'archived')),
  genre text,
  description text,
  explicit boolean not null default false,
  cover_provider text,
  cover_bucket text,
  cover_object_key text,
  -- When it goes (or went) live. Null while it is a pure draft.
  published_at timestamptz,
  -- Where it came from, so the DAW can find its own drafts again.
  source_app text not null default 'apollo-daw',
  -- Set when the artist also shares the release to Scrolls.
  scrolls_post_id uuid references public.posts(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint music_releases_title_length check (
    char_length(trim(title)) between 1 and 160
  ),
  -- Anything visible must have a moment it became visible.
  constraint music_releases_published_has_date check (
    status <> 'published' or published_at is not null
  )
);

create index if not exists music_releases_artist_created_idx
  on public.music_releases (artist_id, created_at desc);
create index if not exists music_releases_owner_status_idx
  on public.music_releases (owner_id, status, updated_at desc);
-- The discovery query: newest published first.
create index if not exists music_releases_published_idx
  on public.music_releases (published_at desc)
  where status = 'published';
create unique index if not exists music_releases_scrolls_post_key
  on public.music_releases (scrolls_post_id)
  where scrolls_post_id is not null;

--------------------------------------------------------------------------------
-- Tracks
--------------------------------------------------------------------------------
create table if not exists public.music_tracks (
  id uuid primary key default gen_random_uuid(),
  release_id uuid not null references public.music_releases(id) on delete cascade,
  owner_id uuid not null references public.users(id) on delete cascade,
  title text not null,
  track_number integer not null default 1 check (track_number between 1 and 999),
  duration_seconds double precision check (duration_seconds is null or duration_seconds > 0),
  -- Musical metadata the DAW already knows at bounce time.
  bpm double precision check (bpm is null or (bpm > 0 and bpm < 400)),
  musical_key text,
  explicit boolean not null default false,
  isrc text,
  lyrics text,
  -- [{ "name": ..., "role": ..., "userId": ... }]
  credits jsonb not null default '[]'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint music_tracks_title_length check (
    char_length(trim(title)) between 1 and 160
  ),
  constraint music_tracks_unique_number unique (release_id, track_number)
);

create index if not exists music_tracks_release_order_idx
  on public.music_tracks (release_id, track_number asc);

--------------------------------------------------------------------------------
-- Track assets
--------------------------------------------------------------------------------
-- One row per file. A track always has a 'master'; waveform and stems are
-- optional and added later without touching the track row.
create table if not exists public.music_track_assets (
  id uuid primary key default gen_random_uuid(),
  track_id uuid not null references public.music_tracks(id) on delete cascade,
  owner_id uuid not null references public.users(id) on delete cascade,
  kind text not null default 'master'
    check (kind in ('master', 'preview', 'waveform', 'stem')),
  -- Free label for stems ("drums", "vocals"); null for a master.
  label text,
  provider text not null default 'r2',
  bucket text,
  object_key text not null,
  mime_type text,
  byte_size bigint check (byte_size is null or byte_size >= 0),
  sample_rate integer,
  channels smallint,
  created_at timestamptz not null default now(),
  constraint music_track_assets_object_key_length check (
    char_length(trim(object_key)) between 1 and 512
  )
);

create index if not exists music_track_assets_track_kind_idx
  on public.music_track_assets (track_id, kind);
-- A track has at most one master and one waveform; stems are many.
create unique index if not exists music_track_assets_single_master_idx
  on public.music_track_assets (track_id, kind)
  where kind in ('master', 'preview', 'waveform');

--------------------------------------------------------------------------------
-- Likes
--------------------------------------------------------------------------------
create table if not exists public.music_likes (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users(id) on delete cascade,
  track_id uuid references public.music_tracks(id) on delete cascade,
  release_id uuid references public.music_releases(id) on delete cascade,
  created_at timestamptz not null default now(),
  -- Exactly one target, so a like is never ambiguous.
  constraint music_likes_one_target check (
    (track_id is not null and release_id is null)
    or (track_id is null and release_id is not null)
  )
);

create unique index if not exists music_likes_user_track_key
  on public.music_likes (user_id, track_id) where track_id is not null;
create unique index if not exists music_likes_user_release_key
  on public.music_likes (user_id, release_id) where release_id is not null;
create index if not exists music_likes_user_created_idx
  on public.music_likes (user_id, created_at desc);

--------------------------------------------------------------------------------
-- Library
--------------------------------------------------------------------------------
create table if not exists public.music_library_items (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users(id) on delete cascade,
  release_id uuid references public.music_releases(id) on delete cascade,
  playlist_id uuid references public.music_playlists(id) on delete cascade,
  sort_order integer not null default 0,
  created_at timestamptz not null default now(),
  constraint music_library_one_target check (
    (release_id is not null and playlist_id is null)
    or (release_id is null and playlist_id is not null)
  )
);

create unique index if not exists music_library_user_release_key
  on public.music_library_items (user_id, release_id) where release_id is not null;
create unique index if not exists music_library_user_playlist_key
  on public.music_library_items (user_id, playlist_id) where playlist_id is not null;
create index if not exists music_library_user_sort_idx
  on public.music_library_items (user_id, sort_order asc, created_at desc);

--------------------------------------------------------------------------------
-- Play events
--------------------------------------------------------------------------------
-- Append-only. user_id is nullable so anonymous listening still counts, and no
-- row is ever updated - corrections are new rows.
create table if not exists public.music_play_events (
  id uuid primary key default gen_random_uuid(),
  track_id uuid not null references public.music_tracks(id) on delete cascade,
  user_id uuid references public.users(id) on delete set null,
  session_id uuid not null,
  -- Daily-rotating hash produced by the Edge Function. Raw network addresses
  -- are never stored, but repeat submissions can still be rate-limited.
  listener_hash text not null,
  played_at timestamptz not null default now(),
  -- How much was actually heard; what separates a play from a skip.
  ms_played integer not null default 0 check (ms_played >= 0),
  completed boolean not null default false,
  source text not null default 'web' check (source in ('web', 'ios', 'android', 'daw')),
  created_at timestamptz not null default now()
);

create index if not exists music_play_events_track_time_idx
  on public.music_play_events (track_id, played_at desc);
create index if not exists music_play_events_user_time_idx
  on public.music_play_events (user_id, played_at desc)
  where user_id is not null;
create index if not exists music_play_events_listener_time_idx
  on public.music_play_events (listener_hash, played_at desc);
create unique index if not exists music_play_events_track_session_key
  on public.music_play_events (track_id, session_id);

--------------------------------------------------------------------------------
-- Row level security
--------------------------------------------------------------------------------
alter table public.music_artists enable row level security;
alter table public.music_releases enable row level security;
alter table public.music_tracks enable row level security;
alter table public.music_track_assets enable row level security;
alter table public.music_likes enable row level security;
alter table public.music_library_items enable row level security;
alter table public.music_play_events enable row level security;

-- Artists are public; only the owner can change one.
drop policy if exists music_artists_select_all on public.music_artists;
create policy music_artists_select_all on public.music_artists
for select using (true);

-- Catalog writes deliberately have no client policy. The apollo-music Edge
-- Function validates the actor and calls the service-role-only transaction
-- below. This prevents a client from supplying its own owner_id while linking
-- a release, track or asset to another user's parent row.
drop policy if exists music_artists_write_owner on public.music_artists;

-- A release is readable when it is published, or by whoever owns it. Drafts stay
-- private, which is what lets /studio hold unreleased work safely.
drop policy if exists music_releases_select_published_or_owner on public.music_releases;
create policy music_releases_select_published_or_owner on public.music_releases
for select using (
  (status = 'published' and published_at is not null and published_at <= now())
  or owner_id = auth.uid()
);

drop policy if exists music_releases_write_owner on public.music_releases;

-- Tracks and assets inherit their release's visibility.
drop policy if exists music_tracks_select_visible on public.music_tracks;
create policy music_tracks_select_visible on public.music_tracks
for select using (
  owner_id = auth.uid()
  or exists (
    select 1 from public.music_releases r
    where r.id = music_tracks.release_id
      and r.status = 'published'
      and r.published_at is not null
      and r.published_at <= now()
  )
);

drop policy if exists music_tracks_write_owner on public.music_tracks;

drop policy if exists music_track_assets_select_visible on public.music_track_assets;
create policy music_track_assets_select_visible on public.music_track_assets
for select using (
  owner_id = auth.uid()
  or exists (
    select 1
    from public.music_tracks t
    join public.music_releases r on r.id = t.release_id
    where t.id = music_track_assets.track_id
      and r.status = 'published'
      and r.published_at is not null
      and r.published_at <= now()
  )
);

drop policy if exists music_track_assets_write_owner on public.music_track_assets;

-- Likes and library belong to the listener alone.
drop policy if exists music_likes_own on public.music_likes;
create policy music_likes_own on public.music_likes
for all using (user_id = auth.uid())
with check (
  user_id = auth.uid()
  and (
    (music_likes.track_id is not null and exists (
      select 1 from public.music_tracks t
      join public.music_releases r on r.id = t.release_id
      where t.id = music_likes.track_id
        and r.status = 'published'
        and r.published_at <= now()
    ))
    or (music_likes.release_id is not null and exists (
      select 1 from public.music_releases r
      where r.id = music_likes.release_id
        and r.status = 'published'
        and r.published_at <= now()
    ))
  )
);

drop policy if exists music_library_own on public.music_library_items;
create policy music_library_own on public.music_library_items
for all using (user_id = auth.uid())
with check (
  user_id = auth.uid()
  and (
    (music_library_items.release_id is not null and exists (
      select 1 from public.music_releases r
      where r.id = music_library_items.release_id
        and r.status = 'published'
        and r.published_at <= now()
    ))
    or (music_library_items.playlist_id is not null and exists (
      select 1 from public.music_playlists p
      where p.id = music_library_items.playlist_id
        and (p.owner_id = auth.uid() or p.visibility in ('public', 'unlisted'))
    ))
  )
);

-- Play writes also go exclusively through the Edge Function. It derives the
-- user, timestamp, completion state and listener hash, then rate-limits before
-- inserting. Clients cannot manufacture royalty-bearing events directly.
drop policy if exists music_play_events_insert_any on public.music_play_events;

drop policy if exists music_play_events_select_own_or_artist on public.music_play_events;
create policy music_play_events_select_own_or_artist on public.music_play_events
for select using (user_id = auth.uid());

--------------------------------------------------------------------------------
-- Keep updated_at honest
--------------------------------------------------------------------------------
create or replace function public.music_touch_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists music_artists_touch on public.music_artists;
create trigger music_artists_touch before update on public.music_artists
for each row execute function public.music_touch_updated_at();

drop trigger if exists music_releases_touch on public.music_releases;
create trigger music_releases_touch before update on public.music_releases
for each row execute function public.music_touch_updated_at();

drop trigger if exists music_tracks_touch on public.music_tracks;
create trigger music_tracks_touch before update on public.music_tracks
for each row execute function public.music_touch_updated_at();

--------------------------------------------------------------------------------
-- Atomic catalog publishing
--------------------------------------------------------------------------------
-- Only the service role may execute this transaction. The apollo-music Edge
-- Function authenticates the request, derives the owner and sanitizes metadata
-- before calling it. Keeping all four inserts here avoids half-created releases.
create or replace function public.apollo_create_release(
  p_owner_id uuid,
  p_artist_handle text,
  p_artist_display_name text,
  p_title text,
  p_release_type text,
  p_genre text,
  p_description text,
  p_explicit boolean,
  p_cover_provider text,
  p_cover_bucket text,
  p_cover_object_key text,
  p_track_title text,
  p_duration_seconds double precision,
  p_bpm double precision,
  p_musical_key text,
  p_track_provider text,
  p_track_bucket text,
  p_track_object_key text,
  p_track_mime_type text,
  p_track_byte_size bigint,
  p_scrolls_post_id uuid default null,
  p_status text default 'published'
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_artist_id uuid;
  v_release_id uuid;
  v_track_id uuid;
  v_asset_id uuid;
  v_expected_prefix text := 'music/' || lower(p_owner_id::text) || '/';
begin
  if not exists (select 1 from public.users u where u.id = p_owner_id) then
    raise exception 'Unknown catalog owner.';
  end if;
  if p_status not in ('draft', 'published') then
    raise exception 'Invalid release status.';
  end if;
  if p_release_type not in ('single', 'ep', 'album') then
    raise exception 'Invalid release type.';
  end if;
  if lower(trim(p_artist_handle)) !~ '^[a-z0-9_.-]{2,32}$' then
    raise exception 'Invalid artist handle.';
  end if;
  if trim(coalesce(p_track_object_key, '')) not like (v_expected_prefix || '%') then
    raise exception 'Track asset is outside the owner namespace.';
  end if;
  if p_cover_object_key is not null
     and trim(p_cover_object_key) not like (v_expected_prefix || '%') then
    raise exception 'Cover asset is outside the owner namespace.';
  end if;

  -- A retried DAW request returns the original release instead of duplicating it.
  if p_scrolls_post_id is not null then
    select r.id into v_release_id
    from public.music_releases r
    where r.scrolls_post_id = p_scrolls_post_id
      and r.owner_id = p_owner_id;

    if v_release_id is not null then
      select t.id into v_track_id
      from public.music_tracks t
      where t.release_id = v_release_id
      order by t.track_number
      limit 1;
      return jsonb_build_object(
        'releaseID', v_release_id,
        'trackID', v_track_id,
        'idempotent', true
      );
    end if;
  end if;

  insert into public.music_artists (owner_id, handle, display_name)
  values (
    p_owner_id,
    lower(trim(p_artist_handle)),
    left(trim(p_artist_display_name), 80)
  )
  on conflict (owner_id) do update
    set display_name = excluded.display_name,
        updated_at = now()
  returning id into v_artist_id;

  insert into public.music_releases (
    artist_id, owner_id, title, release_type, status, genre, description,
    explicit, cover_provider, cover_bucket, cover_object_key, published_at,
    source_app, scrolls_post_id
  ) values (
    v_artist_id, p_owner_id, left(trim(p_title), 160), p_release_type, p_status,
    nullif(left(trim(coalesce(p_genre, '')), 80), ''),
    nullif(left(trim(coalesce(p_description, '')), 4000), ''),
    coalesce(p_explicit, false), p_cover_provider, p_cover_bucket,
    p_cover_object_key, case when p_status = 'published' then now() else null end,
    'apollo-daw', p_scrolls_post_id
  ) returning id into v_release_id;

  insert into public.music_tracks (
    release_id, owner_id, title, track_number, duration_seconds, bpm,
    musical_key, explicit
  ) values (
    v_release_id, p_owner_id, left(trim(p_track_title), 160), 1,
    p_duration_seconds, p_bpm, nullif(left(trim(coalesce(p_musical_key, '')), 32), ''),
    coalesce(p_explicit, false)
  ) returning id into v_track_id;

  insert into public.music_track_assets (
    track_id, owner_id, kind, provider, bucket, object_key, mime_type, byte_size
  ) values (
    v_track_id, p_owner_id, 'master', coalesce(nullif(p_track_provider, ''), 'r2'),
    p_track_bucket, p_track_object_key, p_track_mime_type, p_track_byte_size
  ) returning id into v_asset_id;

  return jsonb_build_object(
    'artistID', v_artist_id,
    'releaseID', v_release_id,
    'trackID', v_track_id,
    'assetID', v_asset_id,
    'idempotent', false
  );
end;
$$;

revoke all on function public.apollo_create_release(
  uuid, text, text, text, text, text, text, boolean, text, text, text,
  text, double precision, double precision, text, text, text, text, text,
  bigint, uuid, text
) from public, anon, authenticated;
grant execute on function public.apollo_create_release(
  uuid, text, text, text, text, text, text, boolean, text, text, text,
  text, double precision, double precision, text, text, text, text, text,
  bigint, uuid, text
) to service_role;

--------------------------------------------------------------------------------
-- Bridge to the existing playlists
--------------------------------------------------------------------------------
-- music_playlist_tracks points at a Scrolls post, and source_post_id is NOT
-- NULL - so a catalog track could not be added to a playlist without inventing
-- a post for it. Make the post optional and require one of the two, so a
-- playlist can mix music published the old way with catalog tracks while the
-- back catalogue is migrated.
alter table public.music_playlist_tracks
  add column if not exists catalog_track_id uuid
  references public.music_tracks(id) on delete cascade;

alter table public.music_playlist_tracks
  alter column source_post_id drop not null;

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'music_playlist_tracks_has_source'
  ) then
    alter table public.music_playlist_tracks
      add constraint music_playlist_tracks_has_source check (
        source_post_id is not null or catalog_track_id is not null
      );
  end if;
end
$$;

create index if not exists music_playlist_tracks_catalog_idx
  on public.music_playlist_tracks (catalog_track_id)
  where catalog_track_id is not null;

-- The original uniqueness key includes source_post_id, which is now nullable and
-- therefore stops de-duplicating catalog entries. Guard those separately.
create unique index if not exists music_playlist_tracks_unique_catalog_idx
  on public.music_playlist_tracks (playlist_id, catalog_track_id)
  where catalog_track_id is not null;
