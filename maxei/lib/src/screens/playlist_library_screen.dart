import 'package:flutter/material.dart';

import '../media/media_item.dart';
import '../media/media_playlist.dart';
import '../theme/maxei_theme.dart';
import '../widgets/media_artwork.dart';

class PlaylistLibraryScreen extends StatefulWidget {
  const PlaylistLibraryScreen({
    super.key,
    required this.playlists,
    required this.mediaItems,
    required this.onChanged,
    required this.onPlay,
  });

  final List<MediaPlaylist> playlists;
  final List<MediaItem> mediaItems;
  final VoidCallback onChanged;
  final ValueChanged<List<MediaItem>> onPlay;

  @override
  State<PlaylistLibraryScreen> createState() => _PlaylistLibraryScreenState();
}

class _PlaylistLibraryScreenState extends State<PlaylistLibraryScreen> {
  Future<void> _createPlaylist() async {
    final name = await showDialog<String>(
      context: context,
      builder: (_) => const _CreatePlaylistDialog(),
    );
    if (!mounted || name == null || name.isEmpty) return;
    setState(() => widget.playlists.add(MediaPlaylist(name)));
    widget.onChanged();
  }

  List<MediaItem> _tracks(MediaPlaylist playlist) {
    final byId = {for (final item in widget.mediaItems) item.id: item};
    return playlist.mediaIds
        .map((id) => byId[id])
        .whereType<MediaItem>()
        .toList();
  }

  Future<void> _openPlaylist(MediaPlaylist playlist) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => _PlaylistDetailScreen(
          playlist: playlist,
          mediaItems: widget.mediaItems,
          onChanged: widget.onChanged,
          onPlay: widget.onPlay,
          onDelete: () {
            setState(
              () => widget.playlists.removeWhere(
                (item) => item.id == playlist.id,
              ),
            );
            widget.onChanged();
          },
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) => CustomScrollView(
    slivers: [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
        sliver: SliverToBoxAdapter(
          child: Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Playlists',
                      style: TextStyle(
                        color: ink,
                        fontSize: 27,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 5),
                    Text(
                      'Vos morceaux, dans l’ordre qui vous ressemble.',
                      style: TextStyle(color: ink, fontSize: 12),
                    ),
                  ],
                ),
              ),
              IconButton.filledTonal(
                tooltip: 'Créer une playlist',
                onPressed: _createPlaylist,
                style: IconButton.styleFrom(
                  backgroundColor: aqua,
                  foregroundColor: ink,
                ),
                icon: const Icon(Icons.add_rounded),
              ),
            ],
          ),
        ),
      ),
      if (widget.playlists.isEmpty)
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.queue_music_rounded, color: ink, size: 42),
                  const SizedBox(height: 14),
                  const Text(
                    'Créez votre première playlist',
                    style: TextStyle(
                      color: ink,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    'Ajoutez des titres, réorganisez-les et lancez votre file.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: ink.withValues(alpha: 0.68),
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 15),
                  FilledButton.icon(
                    onPressed: _createPlaylist,
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Créer une playlist'),
                    style: FilledButton.styleFrom(
                      backgroundColor: ink,
                      foregroundColor: canvas,
                    ),
                  ),
                ],
              ),
            ),
          ),
        )
      else
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
          sliver: SliverList.builder(
            itemCount: widget.playlists.length,
            itemBuilder: (context, index) {
              final playlist = widget.playlists[index];
              final tracks = _tracks(playlist);
              return ListTile(
                leading: MediaArtwork(title: playlist.name, size: 50),
                title: Text(
                  playlist.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: ink,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                subtitle: Text(
                  '${tracks.length} titres',
                  style: TextStyle(
                    color: ink.withValues(alpha: 0.68),
                    fontSize: 11,
                  ),
                ),
                trailing: const Icon(Icons.chevron_right_rounded, color: ink),
                onTap: () => _openPlaylist(playlist),
              );
            },
          ),
        ),
    ],
  );
}

class _CreatePlaylistDialog extends StatefulWidget {
  const _CreatePlaylistDialog();

  @override
  State<_CreatePlaylistDialog> createState() => _CreatePlaylistDialogState();
}

class _CreatePlaylistDialogState extends State<_CreatePlaylistDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() => Navigator.pop(context, _controller.text.trim());

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Nouvelle playlist'),
    content: TextField(
      controller: _controller,
      autofocus: true,
      maxLength: 40,
      textCapitalization: TextCapitalization.sentences,
      decoration: const InputDecoration(hintText: 'Nom de la playlist'),
      onSubmitted: (_) => _submit(),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Annuler'),
      ),
      FilledButton(onPressed: _submit, child: const Text('Créer')),
    ],
  );
}

class _PlaylistDetailScreen extends StatefulWidget {
  const _PlaylistDetailScreen({
    required this.playlist,
    required this.mediaItems,
    required this.onChanged,
    required this.onPlay,
    required this.onDelete,
  });

  final MediaPlaylist playlist;
  final List<MediaItem> mediaItems;
  final VoidCallback onChanged;
  final ValueChanged<List<MediaItem>> onPlay;
  final VoidCallback onDelete;

  @override
  State<_PlaylistDetailScreen> createState() => _PlaylistDetailScreenState();
}

class _PlaylistDetailScreenState extends State<_PlaylistDetailScreen> {
  List<MediaItem> get _tracks {
    final byId = {for (final item in widget.mediaItems) item.id: item};
    return widget.playlist.mediaIds
        .map((id) => byId[id])
        .whereType<MediaItem>()
        .toList();
  }

  Future<void> _addTracks() async {
    final existing = widget.playlist.mediaIds.toSet();
    final available = widget.mediaItems
        .where((item) => !existing.contains(item.id))
        .toList();
    if (available.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Aucun autre média à ajouter.')),
      );
      return;
    }
    final selected = <String>{};
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          child: SizedBox(
            height: MediaQuery.sizeOf(context).height * 0.72,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 12, 8),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Ajouter des médias',
                          style: TextStyle(
                            color: ink,
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          setState(
                            () => widget.playlist.mediaIds.addAll(selected),
                          );
                          widget.onChanged();
                          Navigator.pop(context);
                        },
                        child: const Text('Ajouter'),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: available.length,
                    itemBuilder: (context, index) {
                      final item = available[index];
                      return CheckboxListTile(
                        value: selected.contains(item.id),
                        activeColor: aqua,
                        checkColor: ink,
                        title: Text(
                          item.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(item.artist),
                        secondary: MediaArtwork(title: item.title, size: 42),
                        onChanged: (checked) => setSheetState(() {
                          if (checked == true) {
                            selected.add(item.id);
                          } else {
                            selected.remove(item.id);
                          }
                        }),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  Future<void> _deletePlaylist() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer la playlist ?'),
        content: Text(
          '« ${widget.playlist.name} » sera supprimée. Les fichiers restent dans votre bibliothèque.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Garder'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      widget.onDelete();
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tracks = _tracks;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.playlist.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            tooltip: 'Supprimer la playlist',
            onPressed: _deletePlaylist,
            icon: const Icon(Icons.delete_outline_rounded),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 15),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '${tracks.length} titres',
                    style: TextStyle(
                      color: ink.withValues(alpha: 0.68),
                      fontSize: 12,
                    ),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: _addTracks,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Ajouter'),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  tooltip: 'Lire la playlist',
                  onPressed: tracks.isEmpty
                      ? null
                      : () => widget.onPlay(tracks),
                  style: IconButton.styleFrom(
                    backgroundColor: aqua,
                    foregroundColor: ink,
                  ),
                  icon: const Icon(Icons.play_arrow_rounded),
                ),
              ],
            ),
          ),
          Expanded(
            child: tracks.isEmpty
                ? Center(
                    child: Text(
                      'Ajoutez des titres depuis votre bibliothèque.',
                      style: TextStyle(
                        color: ink.withValues(alpha: 0.68),
                        fontSize: 12,
                      ),
                    ),
                  )
                : ReorderableListView.builder(
                    itemCount: tracks.length,
                    onReorderItem: (oldIndex, newIndex) => setState(() {
                      final id = widget.playlist.mediaIds.removeAt(oldIndex);
                      widget.playlist.mediaIds.insert(newIndex, id);
                      widget.onChanged();
                    }),
                    itemBuilder: (context, index) {
                      final item = tracks[index];
                      return ListTile(
                        key: ValueKey(item.id),
                        leading: MediaArtwork(title: item.title, size: 44),
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
                          style: TextStyle(
                            color: ink.withValues(alpha: 0.66),
                            fontSize: 10,
                          ),
                        ),
                        trailing: IconButton(
                          tooltip: 'Retirer de la playlist',
                          icon: const Icon(
                            Icons.remove_circle_outline_rounded,
                            color: ink,
                          ),
                          onPressed: () => setState(() {
                            widget.playlist.mediaIds.remove(item.id);
                            widget.onChanged();
                          }),
                        ),
                        onTap: () => widget.onPlay(tracks.sublist(index)),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
