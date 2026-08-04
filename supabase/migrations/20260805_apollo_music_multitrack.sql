-- Apollo Music: atomic multi-track publishing for the native app.

alter table public.music_releases
  add column if not exists client_release_id uuid;

create unique index if not exists music_releases_owner_client_key
  on public.music_releases (owner_id, client_release_id)
  where client_release_id is not null;

create or replace function public.apollo_create_release_v2(
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
  p_tracks jsonb,
  p_scrolls_post_id uuid default null,
  p_client_release_id uuid default null,
  p_status text default 'published',
  p_source_app text default 'apollo-ios'
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
  v_track jsonb;
  v_ordinality bigint;
  v_track_title text;
  v_track_number integer;
  v_duration double precision;
  v_bpm double precision;
  v_object_key text;
  v_byte_size bigint;
  v_created_tracks jsonb := '[]'::jsonb;
  v_expected_prefix text := 'music/' || lower(p_owner_id::text) || '/';
begin
  if not exists (select 1 from public.users u where u.id = p_owner_id) then
    raise exception 'Unknown catalog owner.';
  end if;
  if char_length(trim(coalesce(p_title, ''))) not between 1 and 160 then
    raise exception 'Invalid release title.';
  end if;
  if char_length(trim(coalesce(p_artist_display_name, ''))) not between 1 and 80 then
    raise exception 'Invalid artist display name.';
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
  if jsonb_typeof(p_tracks) <> 'array'
     or jsonb_array_length(p_tracks) < 1
     or jsonb_array_length(p_tracks) > 100 then
    raise exception 'A release requires between 1 and 100 tracks.';
  end if;
  if p_cover_object_key is not null
     and trim(p_cover_object_key) not like (v_expected_prefix || '%') then
    raise exception 'Cover asset is outside the owner namespace.';
  end if;

  if exists (
    select 1
    from (
      select case
        when coalesce(value->>'trackNumber', '') ~ '^[0-9]+$'
          then (value->>'trackNumber')::integer
        else ordinality::integer
      end as track_number
      from jsonb_array_elements(p_tracks) with ordinality
    ) numbered
    group by numbered.track_number
    having count(*) > 1
  ) then
    raise exception 'Track numbers must be unique within a release.';
  end if;

  select r.id into v_release_id
  from public.music_releases r
  where r.owner_id = p_owner_id
    and (
      (p_client_release_id is not null and r.client_release_id = p_client_release_id)
      or (p_scrolls_post_id is not null and r.scrolls_post_id = p_scrolls_post_id)
    )
  order by r.created_at
  limit 1;

  if v_release_id is not null then
    select coalesce(
      jsonb_agg(
        jsonb_build_object(
          'trackID', t.id,
          'trackNumber', t.track_number,
          'assetID', a.id
        ) order by t.track_number
      ),
      '[]'::jsonb
    ) into v_created_tracks
    from public.music_tracks t
    left join public.music_track_assets a
      on a.track_id = t.id and a.kind = 'master'
    where t.release_id = v_release_id;

    return jsonb_build_object(
      'releaseID', v_release_id,
      'trackID', v_created_tracks->0->>'trackID',
      'tracks', v_created_tracks,
      'idempotent', true
    );
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
    source_app, scrolls_post_id, client_release_id
  ) values (
    v_artist_id, p_owner_id, left(trim(p_title), 160), p_release_type, p_status,
    nullif(left(trim(coalesce(p_genre, '')), 80), ''),
    nullif(left(trim(coalesce(p_description, '')), 4000), ''),
    coalesce(p_explicit, false), p_cover_provider, p_cover_bucket,
    p_cover_object_key, case when p_status = 'published' then now() else null end,
    left(coalesce(nullif(trim(p_source_app), ''), 'apollo-ios'), 40),
    p_scrolls_post_id, p_client_release_id
  ) returning id into v_release_id;

  for v_track, v_ordinality in
    select value, ordinality
    from jsonb_array_elements(p_tracks) with ordinality
  loop
    v_track_title := left(trim(coalesce(v_track->>'title', '')), 160);
    if v_track_title = '' then
      raise exception 'Every track requires a title.';
    end if;

    v_track_number := case
      when coalesce(v_track->>'trackNumber', '') ~ '^[0-9]+$'
        then (v_track->>'trackNumber')::integer
      else v_ordinality::integer
    end;
    if v_track_number < 1 or v_track_number > 999 then
      raise exception 'Invalid track number.';
    end if;

    v_duration := case
      when coalesce(v_track->>'durationSeconds', '') ~ '^[0-9]+([.][0-9]+)?$'
        then (v_track->>'durationSeconds')::double precision
      else null
    end;
    if v_duration is not null and (v_duration <= 0 or v_duration > 86400) then
      raise exception 'Invalid track duration.';
    end if;

    v_bpm := case
      when coalesce(v_track->>'bpm', '') ~ '^[0-9]+([.][0-9]+)?$'
        then (v_track->>'bpm')::double precision
      else null
    end;
    if v_bpm is not null and (v_bpm <= 0 or v_bpm >= 400) then
      raise exception 'Invalid BPM.';
    end if;

    v_object_key := trim(coalesce(v_track#>>'{asset,objectKey}', ''));
    if v_object_key = '' or v_object_key not like (v_expected_prefix || '%') then
      raise exception 'Track asset is outside the owner namespace.';
    end if;

    v_byte_size := case
      when coalesce(v_track#>>'{asset,byteSize}', '') ~ '^[0-9]+$'
        then (v_track#>>'{asset,byteSize}')::bigint
      else null
    end;

    insert into public.music_tracks (
      release_id, owner_id, title, track_number, duration_seconds, bpm,
      musical_key, explicit, isrc, lyrics, credits
    ) values (
      v_release_id, p_owner_id, v_track_title, v_track_number, v_duration, v_bpm,
      nullif(left(trim(coalesce(v_track->>'musicalKey', '')), 32), ''),
      case when jsonb_typeof(v_track->'explicit') = 'boolean'
        then (v_track->>'explicit')::boolean
        else coalesce(p_explicit, false)
      end,
      nullif(left(trim(coalesce(v_track->>'isrc', '')), 64), ''),
      nullif(left(coalesce(v_track->>'lyrics', ''), 200000), ''),
      case when jsonb_typeof(v_track->'credits') = 'array'
        then v_track->'credits' else '[]'::jsonb end
    ) returning id into v_track_id;

    insert into public.music_track_assets (
      track_id, owner_id, kind, provider, bucket, object_key, mime_type, byte_size
    ) values (
      v_track_id, p_owner_id, 'master',
      coalesce(nullif(v_track#>>'{asset,provider}', ''), 'r2'),
      nullif(v_track#>>'{asset,bucket}', ''), v_object_key,
      nullif(v_track#>>'{asset,mimeType}', ''), v_byte_size
    ) returning id into v_asset_id;

    v_created_tracks := v_created_tracks || jsonb_build_array(jsonb_build_object(
      'trackID', v_track_id,
      'trackNumber', v_track_number,
      'assetID', v_asset_id
    ));
  end loop;

  return jsonb_build_object(
    'artistID', v_artist_id,
    'releaseID', v_release_id,
    'trackID', v_created_tracks->0->>'trackID',
    'tracks', v_created_tracks,
    'idempotent', false
  );
end;
$$;

revoke all on function public.apollo_create_release_v2(
  uuid, text, text, text, text, text, text, boolean, text, text, text,
  jsonb, uuid, uuid, text, text
) from public, anon, authenticated;

grant execute on function public.apollo_create_release_v2(
  uuid, text, text, text, text, text, text, boolean, text, text, text,
  jsonb, uuid, uuid, text, text
) to service_role;
