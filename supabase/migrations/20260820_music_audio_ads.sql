-- Audio ads for Apollo Music.
--
-- One ad plays before the first song of a listening session. Ads are managed by
-- founders from the Apollo web ad portal: audio and cover art are uploaded to
-- storage like any other media, and the row here points at them.
--
-- Rotation is weighted rather than round-robin so a campaign can be given more
-- share of voice without duplicating rows.

create table if not exists public.music_ads (
    id uuid primary key default gen_random_uuid(),
    title text not null,
    advertiser text not null default '',
    -- Where a listener goes if they tap the ad. Optional.
    click_url text,

    -- Media lives in storage; these mirror the provider/bucket/key triple used
    -- by posts, releases and avatars so one resolver serves them all.
    audio_provider text,
    audio_bucket text,
    audio_object_key text not null,
    cover_provider text,
    cover_bucket text,
    cover_object_key text,

    duration_seconds numeric,
    -- Share of voice. Higher weight is picked proportionally more often.
    weight integer not null default 1 check (weight between 1 and 100),
    is_active boolean not null default false,
    -- Optional flight window. Null means "no bound on that end".
    starts_at timestamptz,
    ends_at timestamptz,

    created_by uuid references public.users(id) on delete set null,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);

-- The player asks for eligible ads on almost every first play, so index the
-- exact predicate it filters on.
create index if not exists music_ads_eligible_idx
    on public.music_ads (is_active, starts_at, ends_at)
    where is_active = true;

create table if not exists public.music_ad_impressions (
    id uuid primary key default gen_random_uuid(),
    ad_id uuid not null references public.music_ads(id) on delete cascade,
    -- Null for a signed-out listener; the ad still played.
    user_id uuid references public.users(id) on delete set null,
    session_id text,
    ms_played integer,
    completed boolean not null default false,
    source text not null default 'web',
    created_at timestamptz not null default now()
);

create index if not exists music_ad_impressions_ad_idx
    on public.music_ad_impressions (ad_id, created_at desc);

--------------------------------------------------------------------------------
-- Row level security
--------------------------------------------------------------------------------

alter table public.music_ads enable row level security;
alter table public.music_ad_impressions enable row level security;

-- Listeners may read only ads that are actually eligible to play right now.
-- This is what lets an anonymous visitor hear an ad without exposing drafts,
-- paused campaigns or anything scheduled for the future.
drop policy if exists music_ads_select_eligible on public.music_ads;
create policy music_ads_select_eligible on public.music_ads
    for select
    using (
        is_active = true
        and (starts_at is null or starts_at <= now())
        and (ends_at is null or ends_at >= now())
    );

-- Founders see everything, including drafts and finished campaigns.
drop policy if exists music_ads_select_founder on public.music_ads;
create policy music_ads_select_founder on public.music_ads
    for select
    using (
        exists (
            select 1
            from public.users u
            where u.id = auth.uid()
              and u.is_founder = true
        )
    );

drop policy if exists music_ads_write_founder on public.music_ads;
create policy music_ads_write_founder on public.music_ads
    for all
    using (
        exists (
            select 1
            from public.users u
            where u.id = auth.uid()
              and u.is_founder = true
        )
    )
    with check (
        exists (
            select 1
            from public.users u
            where u.id = auth.uid()
              and u.is_founder = true
        )
    );

-- Anyone may record that an ad played, including signed-out listeners, or the
-- count would only ever reflect logged-in traffic.
drop policy if exists music_ad_impressions_insert_any on public.music_ad_impressions;
create policy music_ad_impressions_insert_any on public.music_ad_impressions
    for insert
    with check (true);

-- Reading the impression log is a founder-only report.
drop policy if exists music_ad_impressions_select_founder on public.music_ad_impressions;
create policy music_ad_impressions_select_founder on public.music_ad_impressions
    for select
    using (
        exists (
            select 1
            from public.users u
            where u.id = auth.uid()
              and u.is_founder = true
        )
    );

--------------------------------------------------------------------------------

drop trigger if exists music_ads_touch_updated_at on public.music_ads;
create trigger music_ads_touch_updated_at
    before update on public.music_ads
    for each row
    execute function public.music_touch_updated_at();
