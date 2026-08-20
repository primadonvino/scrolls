-- Apollo Radio now-playing links stay authoritative by referencing the
-- published Apollo catalog instead of copying editable song metadata.

alter table public.live_stream_sessions
  add column if not exists now_playing_track_id uuid
    references public.music_tracks(id) on delete set null,
  add column if not exists now_playing_updated_at timestamptz;

create index if not exists live_stream_sessions_now_playing_track_idx
  on public.live_stream_sessions (now_playing_track_id)
  where now_playing_track_id is not null;

alter table public.music_library_items
  add column if not exists track_id uuid
    references public.music_tracks(id) on delete cascade;

alter table public.music_library_items
  drop constraint if exists music_library_one_target;

alter table public.music_library_items
  add constraint music_library_one_target check (
    num_nonnulls(release_id, playlist_id, track_id) = 1
  );

create unique index if not exists music_library_user_track_key
  on public.music_library_items (user_id, track_id)
  where track_id is not null;

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
    or (music_library_items.track_id is not null and exists (
      select 1
      from public.music_tracks t
      join public.music_releases r on r.id = t.release_id
      where t.id = music_library_items.track_id
        and r.status = 'published'
        and r.published_at <= now()
    ))
  )
);

comment on column public.live_stream_sessions.now_playing_track_id is
  'Published Apollo catalog track selected by the radio broadcaster.';

comment on column public.music_library_items.track_id is
  'Individual song saved to an Apollo listener catalog.';
