alter table public.live_stream_sessions
  add column if not exists broadcast_kind text not null default 'video';

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'live_stream_sessions_broadcast_kind_check'
      and conrelid = 'public.live_stream_sessions'::regclass
  ) then
    alter table public.live_stream_sessions
      add constraint live_stream_sessions_broadcast_kind_check
      check (broadcast_kind in ('video', 'radio'));
  end if;
end
$$;

create index if not exists live_stream_sessions_active_radio_idx
  on public.live_stream_sessions (started_at desc)
  where status = 'active' and broadcast_kind = 'radio';

comment on column public.live_stream_sessions.broadcast_kind is
  'Distinguishes standard video live sessions from Apollo audio-radio broadcasts.';
