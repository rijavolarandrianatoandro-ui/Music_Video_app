import 'package:flutter/material.dart';

import '../media/music_discovery_catalog.dart';
import '../theme/maxei_theme.dart';
import '../widgets/pixel_artist_avatar.dart';

class ArtistSelectionDialog extends StatefulWidget {
  const ArtistSelectionDialog({super.key, required this.initialSelection});

  final List<String> initialSelection;

  @override
  State<ArtistSelectionDialog> createState() => _ArtistSelectionDialogState();
}

class _ArtistSelectionDialogState extends State<ArtistSelectionDialog> {
  late final Set<String> _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.initialSelection
        .where((id) => artistById(id) != null)
        .take(5)
        .toSet();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Choisissez vos artistes'),
    content: SizedBox(
      width: 440,
      height: 480,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${_selected.length} sur 5 sélectionnés',
            style: const TextStyle(color: aqua, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: GridView.builder(
              itemCount: featuredArtists.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 2.45,
              ),
              itemBuilder: (context, index) {
                final artist = featuredArtists[index];
                final selected = _selected.contains(artist.id);
                return Material(
                  color: selected
                      ? aqua.withValues(alpha: 0.18)
                      : surface.withValues(alpha: 0.9),
                  shape: ContinuousRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: BorderSide(
                      color: selected ? aqua : ink.withValues(alpha: 0.08),
                    ),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    key: ValueKey('artist-${artist.id}'),
                    onTap: () => setState(() {
                      if (selected) {
                        _selected.remove(artist.id);
                      } else if (_selected.length < 5) {
                        _selected.add(artist.id);
                      }
                    }),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Row(
                        children: [
                          PixelArtistAvatar(artistId: artist.id, size: 40),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              artist.name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: ink,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          if (selected)
                            const Icon(
                              Icons.check_circle_rounded,
                              color: aqua,
                              size: 18,
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Illustrations pixel générées sur votre appareil, non '
            'photographiques et sans ressemblance avec les artistes.',
            style: TextStyle(color: mutedInk, fontSize: 11),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context, <String>[]),
        child: const Text('Plus tard'),
      ),
      FilledButton(
        onPressed: _selected.length == 5
            ? () => Navigator.pop(context, _selected.toList(growable: false))
            : null,
        child: const Text('Enregistrer'),
      ),
    ],
  );
}
