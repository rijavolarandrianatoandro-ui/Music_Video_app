import 'package:flutter/material.dart';

import '../media/media_item.dart';
import '../media/media_playlist.dart';
import 'media_library_screen.dart';
import '../theme/maxei_theme.dart';
import '../widgets/liquid_surface.dart';
import '../widgets/media_artwork.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    required this.items,
    required this.playlists,
    required this.query,
    required this.onImport,
    required this.onOpen,
    required this.onFavorite,
    required this.onSelectMediaFilter,
    required this.onOpenPlaylists,
  });

  final List<MediaItem> items;
  final List<MediaPlaylist> playlists;
  final String query;
  final VoidCallback onImport;
  final ValueChanged<MediaItem> onOpen;
  final ValueChanged<MediaItem> onFavorite;
  final ValueChanged<MediaLibraryFilter> onSelectMediaFilter;
  final VoidCallback onOpenPlaylists;

  @override
  Widget build(BuildContext context) {
    if (query.isNotEmpty) {
      final results = items
          .where(
            (item) =>
                item.title.toLowerCase().contains(query) ||
                item.artist.toLowerCase().contains(query),
          )
          .toList();
      return _SearchResults(items: results, onOpen: onOpen);
    }

    final popular = items.toList()
      ..sort((a, b) {
        final byPlays = b.playCount.compareTo(a.playCount);
        return byPlays != 0 ? byPlays : a.title.compareTo(b.title);
      });
    final featured = popular.isEmpty ? null : popular.first;
    final audioCount = items
        .where((item) => item.kind == MediaKind.audio)
        .length;
    final videoCount = items.length - audioCount;

    return ListView(
      key: const ValueKey('home-feed'),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 26),
      children: [
        Text(
          'BONJOUR, MAXEI',
          style: TextStyle(
            color: ink.withValues(alpha: 0.62),
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.7,
          ),
        ),
        const SizedBox(height: 5),
        const Text(
          'La musique,\nà votre rythme.',
          style: TextStyle(
            color: ink,
            fontSize: 29,
            fontWeight: FontWeight.w800,
            height: 1.08,
          ),
        ),
        const SizedBox(height: 15),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _HomeFilterChip(
                label: 'Tout',
                selected: true,
                onTap: () => onSelectMediaFilter(MediaLibraryFilter.all),
              ),
              _HomeFilterChip(
                label: 'Morceaux',
                onTap: () => onSelectMediaFilter(MediaLibraryFilter.audio),
              ),
              _HomeFilterChip(
                label: 'Vidéos',
                onTap: () => onSelectMediaFilter(MediaLibraryFilter.video),
              ),
              _HomeFilterChip(
                label: 'Favoris',
                onTap: () => onSelectMediaFilter(MediaLibraryFilter.favorites),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _FeaturedHero(item: featured, onImport: onImport, onOpen: onOpen),
        const SizedBox(height: 22),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const _SectionHeading(title: 'Votre collection'),
            IconButton(
              tooltip: 'Ajouter des médias',
              onPressed: onImport,
              icon: const Icon(Icons.add_rounded, color: ink),
            ),
          ],
        ),
        const SizedBox(height: 5),
        Row(
          children: [
            Expanded(
              child: _CollectionTile(
                icon: Icons.music_note_rounded,
                title: 'Musique',
                count: audioCount,
                onTap: () => onSelectMediaFilter(MediaLibraryFilter.audio),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _CollectionTile(
                icon: Icons.movie_rounded,
                title: 'Vidéos',
                count: videoCount,
                onTap: () => onSelectMediaFilter(MediaLibraryFilter.video),
              ),
            ),
          ],
        ),
        if (popular.isNotEmpty) ...[
          const SizedBox(height: 22),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const _SectionHeading(title: 'Populaires'),
              TextButton(
                onPressed: () => onSelectMediaFilter(MediaLibraryFilter.all),
                style: TextButton.styleFrom(foregroundColor: ink),
                child: const Text('Tout voir'),
              ),
            ],
          ),
          for (final item in popular.take(6))
            _MediaRow(
              item: item,
              onTap: () => onOpen(item),
              onFavorite: () => onFavorite(item),
            ),
        ],
        const SizedBox(height: 18),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const _SectionHeading(title: 'Playlists'),
            TextButton.icon(
              onPressed: onOpenPlaylists,
              icon: const Icon(Icons.arrow_forward_rounded, size: 16),
              label: const Text('Gérer'),
              style: TextButton.styleFrom(foregroundColor: ink),
            ),
          ],
        ),
        if (playlists.isEmpty)
          _EmptyPlaylists(onOpen: onOpenPlaylists)
        else
          for (final playlist in playlists.take(3))
            _PlaylistRow(playlist: playlist, onTap: onOpenPlaylists),
      ],
    );
  }
}

class _HomeFilterChip extends StatelessWidget {
  const _HomeFilterChip({
    required this.label,
    required this.onTap,
    this.selected = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(right: 7),
    child: Material(
      color: selected ? aqua : canvas.withValues(alpha: 0.48),
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          child: Text(
            label,
            style: TextStyle(
              color: ink,
              fontSize: 11,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ),
    ),
  );
}

class _FeaturedHero extends StatelessWidget {
  const _FeaturedHero({
    required this.item,
    required this.onImport,
    required this.onOpen,
  });

  final MediaItem? item;
  final VoidCallback onImport;
  final ValueChanged<MediaItem> onOpen;

  @override
  Widget build(BuildContext context) => LiquidGlass(
    radius: 20,
    tint: ink.withValues(alpha: 0.9),
    padding: const EdgeInsets.all(18),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'À ÉCOUTER',
                style: TextStyle(
                  color: aqua,
                  fontWeight: FontWeight.w700,
                  fontSize: 10,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                item?.title ?? 'Votre prochain morceau',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: canvas,
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                item?.artist ?? 'Importez votre musique pour commencer',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: canvas.withValues(alpha: 0.72),
                  fontSize: 11,
                ),
              ),
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: item == null ? onImport : () => onOpen(item!),
                icon: Icon(
                  item == null ? Icons.add_rounded : Icons.play_arrow_rounded,
                  size: 17,
                ),
                label: Text(item == null ? 'Ajouter des médias' : 'Écouter'),
                style: TextButton.styleFrom(
                  foregroundColor: ink,
                  backgroundColor: aqua,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        if (item == null)
          const MediaArtwork(title: 'Maxei', size: 92)
        else
          MediaArtwork(title: item!.title, size: 92),
      ],
    ),
  );
}

class _CollectionTile extends StatelessWidget {
  const _CollectionTile({
    required this.icon,
    required this.title,
    required this.count,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => LiquidGlass(
    radius: 12,
    tint: aqua.withValues(alpha: 0.36),
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(13),
          child: Row(
            children: [
              Icon(icon, color: ink, size: 21),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: ink,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      '$count éléments',
                      style: const TextStyle(color: ink, fontSize: 10),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios_rounded, color: ink, size: 12),
            ],
          ),
        ),
      ),
    ),
  );
}

class _EmptyPlaylists extends StatelessWidget {
  const _EmptyPlaylists({required this.onOpen});
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: const Icon(Icons.queue_music_rounded, color: ink),
    title: const Text(
      'Composez votre prochaine file',
      style: TextStyle(color: ink, fontSize: 12),
    ),
    trailing: IconButton(
      tooltip: 'Créer une playlist',
      onPressed: onOpen,
      icon: const Icon(Icons.add_rounded, color: ink),
    ),
  );
}

class _PlaylistRow extends StatelessWidget {
  const _PlaylistRow({required this.playlist, required this.onTap});
  final MediaPlaylist playlist;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: MediaArtwork(title: playlist.name, size: 44),
    title: Text(
      playlist.name,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(
        color: ink,
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
    ),
    subtitle: Text(
      '${playlist.mediaIds.length} titres',
      style: TextStyle(color: ink.withValues(alpha: 0.65), fontSize: 10),
    ),
    trailing: const Icon(Icons.chevron_right_rounded, color: ink),
    onTap: onTap,
  );
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) => Text(
    title,
    style: const TextStyle(
      color: ink,
      fontSize: 16,
      fontWeight: FontWeight.w800,
    ),
  );
}

class _MediaRow extends StatelessWidget {
  const _MediaRow({
    required this.item,
    required this.onTap,
    required this.onFavorite,
  });
  final MediaItem item;
  final VoidCallback onTap;
  final VoidCallback onFavorite;

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: MediaArtwork(title: item.title, size: 48),
    title: Text(
      item.title,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(
        color: ink,
        fontSize: 13,
        fontWeight: FontWeight.w600,
      ),
    ),
    subtitle: Text(
      item.artist,
      style: TextStyle(color: ink.withValues(alpha: 0.65), fontSize: 11),
    ),
    trailing: IconButton(
      tooltip: item.isFavorite ? 'Retirer des favoris' : 'Ajouter aux favoris',
      onPressed: onFavorite,
      icon: Icon(
        item.isFavorite
            ? Icons.favorite_rounded
            : Icons.favorite_border_rounded,
        color: ink,
        size: 19,
      ),
    ),
    onTap: onTap,
  );
}

class _SearchResults extends StatelessWidget {
  const _SearchResults({required this.items, required this.onOpen});
  final List<MediaItem> items;
  final ValueChanged<MediaItem> onOpen;

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(20),
    children: [
      const Text(
        'Résultats',
        style: TextStyle(color: ink, fontSize: 22, fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: 12),
      if (items.isEmpty)
        const Text(
          'Aucun média ne correspond à cette recherche.',
          style: TextStyle(color: ink, fontSize: 13),
        )
      else
        for (final item in items)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: MediaArtwork(title: item.title, size: 48),
            title: Text(
              item.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: ink),
            ),
            subtitle: Text(
              item.kind == MediaKind.audio
                  ? 'Audio · ${item.artist}'
                  : 'Vidéo · ${item.sizeLabel}',
              style: const TextStyle(color: ink, fontSize: 11),
            ),
            trailing: Icon(
              item.kind == MediaKind.audio
                  ? Icons.play_arrow_rounded
                  : Icons.play_circle_outline_rounded,
              color: ink,
            ),
            onTap: () => onOpen(item),
          ),
    ],
  );
}
