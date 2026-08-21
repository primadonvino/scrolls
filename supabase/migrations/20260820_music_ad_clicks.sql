-- Ad click-throughs.
--
-- Plays are already counted in music_ad_impressions. A redirect is a different
-- event with a different value to an advertiser - it happens after the play,
-- may never happen at all, and can happen more than once - so it is recorded on
-- its own rather than as a flag on the impression.

create table if not exists public.music_ad_clicks (
    id uuid primary key default gen_random_uuid(),
    ad_id uuid not null references public.music_ads(id) on delete cascade,
    -- Null for a signed-out listener; the click still counts.
    user_id uuid references public.users(id) on delete set null,
    session_id text,
    source text not null default 'web',
    created_at timestamptz not null default now()
);

create index if not exists music_ad_clicks_ad_idx
    on public.music_ad_clicks (ad_id, created_at desc);

alter table public.music_ad_clicks enable row level security;

-- Anyone may record a click, including signed-out listeners, or the count would
-- only ever reflect logged-in traffic.
drop policy if exists music_ad_clicks_insert_any on public.music_ad_clicks;
create policy music_ad_clicks_insert_any on public.music_ad_clicks
    for insert
    with check (true);

-- Reading the log is a founder-only report, like impressions.
drop policy if exists music_ad_clicks_select_founder on public.music_ad_clicks;
create policy music_ad_clicks_select_founder on public.music_ad_clicks
    for select
    using (
        exists (
            select 1
            from public.users u
            where u.id = auth.uid()
              and u.is_founder = true
        )
    );
