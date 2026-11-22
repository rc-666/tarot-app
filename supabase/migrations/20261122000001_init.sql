-- Tarot app: initial schema (2026-11-22)
-- Personal data: profiles hold birth data (LGPD). Every user table has RLS; deletion cascades from auth.users.

create table public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  first_name text not null check (char_length(first_name) between 1 and 60),
  birth_date date not null,
  birth_time time,                       -- null = "I don't know"
  birth_place text,                      -- display name, e.g. "São Paulo, SP, Brazil"
  birth_lat double precision,
  birth_lon double precision,
  birth_tz text,                         -- IANA zone of the birth place
  tz text not null default 'America/Sao_Paulo', -- current phone time zone, updated by the app
  sun_sign text not null check (sun_sign in ('aries','taurus','gemini','cancer','leo','virgo','libra','scorpio','sagittarius','capricorn','aquarius','pisces')),
  natal_sun double precision,            -- ecliptic longitude, filled by compute-sky
  natal_moon double precision,           -- only with birth time + place
  focus_topics text[] not null default '{}' check (cardinality(focus_topics) between 1 and 2),
  language text not null default 'pt' check (language in ('en','pt','es')),
  is_adult boolean not null check (is_adult),  -- 18+ checkbox
  notify_morning boolean not null default true,
  notify_mood boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Sign-level cards: one row per local day, time zone and sign. Public read.
create table public.daily_cards (
  day date not null,
  tz text not null,
  sign text not null,
  influence_planet text not null,
  influence_card text not null,
  influence_reversed boolean not null,
  influence_aspect text,                 -- null = ruler fallback
  advice_card text not null,
  moon_sign text not null,
  computed_at timestamptz not null default now(),
  primary key (day, tz, sign)
);

-- Personal cards for users with birth data.
create table public.user_daily_cards (
  user_id uuid not null references auth.users (id) on delete cascade,
  day date not null,
  influence_planet text not null,
  influence_card text not null,
  influence_reversed boolean not null,
  influence_aspect text,
  advice_card text not null,
  moon_sign text not null,
  computed_at timestamptz not null default now(),
  primary key (user_id, day)
);

-- Moon decan ingresses (mood card changes). Same moment worldwide. Public read.
create table public.mood_shifts (
  at timestamptz primary key,
  decan smallint not null check (decan between 0 and 35),
  card text not null,
  moon_sign text not null
);

-- One reading per local day: topic chosen and the thumbs rating.
create table public.readings (
  user_id uuid not null references auth.users (id) on delete cascade,
  day date not null,
  topic text not null,
  rating smallint check (rating in (-1, 1)),
  created_at timestamptz not null default now(),
  primary key (user_id, day)
);

alter table public.profiles enable row level security;
alter table public.daily_cards enable row level security;
alter table public.user_daily_cards enable row level security;
alter table public.mood_shifts enable row level security;
alter table public.readings enable row level security;

-- profiles: own row only
create policy profiles_select on public.profiles for select to authenticated using (id = auth.uid());
create policy profiles_insert on public.profiles for insert to authenticated with check (id = auth.uid());
create policy profiles_update on public.profiles for update to authenticated using (id = auth.uid()) with check (id = auth.uid());

-- public sky data: read for everyone (first reading happens before sign-up); writes only by service role
create policy daily_cards_read on public.daily_cards for select to anon, authenticated using (true);
create policy mood_shifts_read on public.mood_shifts for select to anon, authenticated using (true);

-- personal cards: read own
create policy user_daily_cards_read on public.user_daily_cards for select to authenticated using (user_id = auth.uid());

-- readings: own rows; rating can be set once (enforced by trigger below)
create policy readings_select on public.readings for select to authenticated using (user_id = auth.uid());
create policy readings_insert on public.readings for insert to authenticated with check (user_id = auth.uid());
create policy readings_update on public.readings for update to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());

create or replace function public.readings_guard() returns trigger language plpgsql as $$
begin
  if old.rating is not null and new.rating is distinct from old.rating then
    raise exception 'rating already given for this day';
  end if;
  if new.day <> old.day or new.user_id <> old.user_id then
    raise exception 'day and user cannot change';
  end if;
  return new;
end $$;
create trigger readings_guard before update on public.readings for each row execute function public.readings_guard();

create or replace function public.touch_updated_at() returns trigger language plpgsql as $$
begin new.updated_at := now(); return new; end $$;
create trigger profiles_touch before update on public.profiles for each row execute function public.touch_updated_at();

-- Natal points are written only by the service role (compute-sky).
-- When birth details change, they are cleared and recomputed by the next cron run (applies from tomorrow's cards).
create or replace function public.profiles_guard_natal() returns trigger language plpgsql as $$
begin
  if coalesce(auth.role(), '') <> 'service_role' then
    if tg_op = 'INSERT' then
      new.natal_sun := null; new.natal_moon := null;
    else
      new.natal_sun := old.natal_sun; new.natal_moon := old.natal_moon;
      if (new.birth_date, new.birth_time, new.birth_tz) is distinct from (old.birth_date, old.birth_time, old.birth_tz) then
        new.natal_sun := null; new.natal_moon := null;
      end if;
    end if;
  end if;
  return new;
end $$;
create trigger profiles_guard_natal before insert or update on public.profiles for each row execute function public.profiles_guard_natal();

create index mood_shifts_at_idx on public.mood_shifts (at);
create index daily_cards_day_idx on public.daily_cards (day);
