-- Concerts.
--
-- Unlike music videos, a concert has no Scrolls equivalent to sync from - it is
-- new data an artist enters in the Apollo web portal, so it needs a table and a
-- write path of its own.

create table if not exists public.music_concerts (
    id uuid primary key default gen_random_uuid(),
    -- The artist account the date belongs to.
    owner_id uuid not null references public.users(id) on delete cascade,

    title text not null default '',
    venue text not null default '',
    city text not null default '',
    country text not null default '',
    -- When the doors open, in UTC. A date with no time is stored at midnight.
    starts_at timestamptz not null,
    ticket_url text,
    notes text,
    -- A cancelled date stays visible with its status rather than vanishing.
    status text not null default 'scheduled'
        check (status in ('scheduled', 'cancelled', 'sold_out')),

    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);

-- The profile lists an artist's dates newest-upcoming first, which is the only
-- query this table serves.
create index if not exists music_concerts_owner_idx
    on public.music_concerts (owner_id, starts_at);

alter table public.music_concerts enable row level security;

-- Concert dates are public information; that is the point of listing them.
drop policy if exists music_concerts_select_all on public.music_concerts;
create policy music_concerts_select_all on public.music_concerts
    for select
    using (true);

-- An artist manages only their own dates.
drop policy if exists music_concerts_write_owner on public.music_concerts;
create policy music_concerts_write_owner on public.music_concerts
    for all
    using (owner_id = (select auth.uid()))
    with check (owner_id = (select auth.uid()));

drop trigger if exists music_concerts_touch_updated_at on public.music_concerts;
create trigger music_concerts_touch_updated_at
    before update on public.music_concerts
    for each row
    execute function public.music_touch_updated_at();
