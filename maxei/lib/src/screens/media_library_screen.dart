import 'package:flutter/material.dart';

import '../media/media_item.dart';
import '../theme/maxei_theme.dart';
import '../widgets/media_artwork.dart';

enum MediaLibraryFilter { all, audio, video, recent, favorites }

class MediaLibraryScreen extends StatelessWidget {
  const MediaLibraryScreen({
    super.key,
    required this.title,
    required this.items,
    required this.query,
    required this.filter,
    required this.onFilterChanged,
    required this.onImport,
    required this.onOpen,
    required this.onFavorite,
  });

  final String title;
  final List<MediaItem> items;
  final String query;
  final MediaLibraryFilter filter;
  final ValueChanged<MediaLibraryFilter> onFilterChanged;
  final VoidCallback onImport;
  final ValueChanged<MediaItem> onOpen;
  final ValueChanged<MediaItem> onFavorite;

  @override
  Widget build(BuildContext context) {
    final items = this.items.where((item) {
      final matchesQuery =
          item.title.toLowerCase().contains(query) ||
          item.artist.toLowerCase().contains(query);
      return matchesQuery &&
          switch (filter) {
            MediaLibraryFilter.all => true,
            MediaLibraryFilter.audio => item.kind == MediaKind.audio,
            MediaLibraryFilter.video => item.kind == MediaKind.video,
            MediaLibraryFilter.recent => item.lastPlayedAt != null,
            MediaLibraryFilter.favorites => item.isFavorite,
          };
    }).toList();
    if (filter == MediaLibraryFilter.recent) {
      items.sort((a, b) => b.lastPlayedAt!.compareTo(a.lastPlayedAt!));
    }

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: ink,
                    fontSize: 27,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  '${items.length} éléments',
                  style: TextStyle(
                    color: ink.withValues(alpha: 0.65),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 13),
                Wrap(
                  spacing: 8,
                  children: [
                    _FilterChip(
                      label: 'Tout',
                      selected: filter == MediaLibraryFilter.all,
                      onTap: () => onFilterChanged(MediaLibraryFilter.all),
                    ),
                    _FilterChip(
                      label: 'Morceaux',
                      selected: filter == MediaLibraryFilter.audio,
                      onTap: () => onFilterChanged(MediaLibraryFilter.audio),
                    ),
                    _FilterChip(
                      label: 'Vidéos',
                      selected: filter == MediaLibraryFilter.video,
                      onTap: () => onFilterChanged(MediaLibraryFilter.video),
                    ),
                    _FilterChip(
                      label: 'Récents',
                      selected: filter == MediaLibraryFilter.recent,
                      onTap: () => onFilterChanged(MediaLibraryFilter.recent),
                    ),
                    _FilterChip(
                      label: 'Favoris',
                      selected: filter == MediaLibraryFilter.favorites,
                      onTap: () =>
                          onFilterChanged(MediaLibraryFilter.favorites),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        if (items.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.library_music_outlined,
                      color: ink,
                      size: 40,
                    ),
                    const SizedBox(height: 13),
                    Text(
                      _emptyTitle(),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: ink,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      _emptySubtitle(),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: ink.withValues(alpha: 0.68),
                        fontSize: 12,
                      ),
                    ),
                    if (query.isEmpty &&
                        filter != MediaLibraryFilter.recent &&
                        filter != MediaLibraryFilter.favorites) ...[
                      const SizedBox(height: 15),
                      FilledButton.icon(
                        onPressed: onImport,
                        icon: const Icon(Icons.add_rounded),
                        label: const Text('Importer des médias'),
                        style: FilledButton.styleFrom(
                          backgroundColor: ink,
                          foregroundColor: canvas,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(12, 7, 12, 22),
            sliver: SliverList.builder(
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
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
                    '${item.kind == MediaKind.audio ? item.artist : 'Vidéo'} · ${item.sizeLabel}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: ink.withValues(alpha: 0.65),
                      fontSize: 10,
                    ),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: item.isFavorite
                            ? 'Retirer des favoris'
                            : 'Ajouter aux favoris',
                        onPressed: () => onFavorite(item),
                        icon: Icon(
                          item.isFavorite
                              ? Icons.favorite_rounded
                              : Icons.favorite_border_rounded,
                          color: ink,
                          size: 19,
                        ),
                      ),
                      Icon(
                        item.kind == MediaKind.audio
                            ? Icons.play_arrow_rounded
                            : Icons.play_circle_outline_rounded,
                        color: ink,
                      ),
                    ],
                  ),
                  onTap: () => onOpen(item),
                );
              },
            ),
          ),
      ],
    );
  }

  String _emptyTitle() {
    if (query.isNotEmpty) {
      return 'Aucun résultat trouvé.';
    }
    if (filter == MediaLibraryFilter.recent) {
      return 'Rien d’écouté ou vu récemment.';
    }
    if (filter == MediaLibraryFilter.favorites) {
      return 'Aucun favori pour le moment.';
    }
    return 'Votre collection commence ici.';
  }

  String _emptySubtitle() => query.isEmpty && filter == MediaLibraryFilter.all
      ? 'Importez des fichiers. Ils restent sur votre appareil.'
      : 'Essayez un autre filtre ou ajoutez un média.';
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: selected ? aqua : canvas,
    borderRadius: BorderRadius.circular(20),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: ink.withValues(alpha: selected ? 0 : 0.2)),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: ink,
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    ),
  );
}
