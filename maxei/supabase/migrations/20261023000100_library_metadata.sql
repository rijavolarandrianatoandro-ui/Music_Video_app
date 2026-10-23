create table public.library_items (
  user_id uuid not null references auth.users (id) on delete cascade,
  item_key text not null check (char_length(item_key) between 1 and 256),
  file_name text not null check (char_length(file_name) between 1 and 512),
  title text not null check (char_length(title) between 1 and 300),
  artist text not null check (char_length(artist) between 1 and 300),
  media_kind text not null check (media_kind in ('audio', 'video')),
  size_bytes bigint not null check (size_bytes >= 0),
  is_favorite boolean not null default false,
  play_count integer not null default 0 check (play_count >= 0),
  last_played_at timestamptz,
  updated_at timestamptz not null default now(),
  primary key (user_id, item_key)
);

create table public.library_playlists (
  user_id uuid not null references auth.users (id) on delete cascade,
  playlist_id text not null check (char_length(playlist_id) between 1 and 128),
  name text not null check (char_length(name) between 1 and 100),
  updated_at timestamptz not null default now(),
  primary key (user_id, playlist_id)
);

create table public.library_playlist_items (
  user_id uuid not null,
  playlist_id text not null,
  item_key text not null,
  position integer not null check (position >= 0),
  primary key (user_id, playlist_id, item_key),
  unique (user_id, playlist_id, position),
  foreign key (user_id, playlist_id)
    references public.library_playlists (user_id, playlist_id)
    on delete cascade,
  foreign key (user_id, item_key)
    references public.library_items (user_id, item_key)
    on delete cascade
);

alter table public.library_items enable row level security;
alter table public.library_playlists enable row level security;
alter table public.library_playlist_items enable row level security;

revoke all on table
  public.library_items,
  public.library_playlists,
  public.library_playlist_items
from anon, authenticated;

grant select, insert, update, delete on table
  public.library_items,
  public.library_playlists,
  public.library_playlist_items
to authenticated;

create policy "Users manage only their library items"
on public.library_items
for all
to authenticated
using ((select auth.uid()) = user_id)
with check ((select auth.uid()) = user_id);

create policy "Users manage only their playlists"
on public.library_playlists
for all
to authenticated
using ((select auth.uid()) = user_id)
with check ((select auth.uid()) = user_id);

create policy "Users manage only their playlist items"
on public.library_playlist_items
for all
to authenticated
using ((select auth.uid()) = user_id)
with check ((select auth.uid()) = user_id);
