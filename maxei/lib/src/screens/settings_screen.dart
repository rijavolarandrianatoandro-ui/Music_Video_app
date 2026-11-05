import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../media/app_settings.dart';
import '../media/media_item.dart';
import '../media/music_discovery_catalog.dart';
import '../media/playback_controller.dart';
import '../theme/maxei_theme.dart';
import '../widgets/liquid_surface.dart';
import '../widgets/pixel_artist_avatar.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({
    super.key,
    required this.settings,
    required this.playback,
    required this.onChanged,
    required this.onThemeModeChanged,
    required this.onOpenRecap,
    required this.hiddenAudioItems,
    required this.onEditArtists,
  });

  final AppSettings settings;
  final PlaybackController playback;
  final Future<void> Function() onChanged;
  final ValueChanged<AppThemeMode> onThemeModeChanged;
  final VoidCallback onOpenRecap;
  final List<MediaItem> hiddenAudioItems;
  final VoidCallback onEditArtists;

  Future<void> _save(BuildContext context) async {
    try {
      await onChanged();
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Impossible d’enregistrer ce réglage : $error'),
          ),
        );
      }
    }
  }

  String _repeatLabel(PlaybackRepeatMode mode) => switch (mode) {
    PlaybackRepeatMode.off => 'Désactivée',
    PlaybackRepeatMode.all => 'Toute la file',
    PlaybackRepeatMode.one => 'Titre en cours',
  };

  Future<void> _openYoutubeTerms(BuildContext context) async {
    try {
      final opened = await launchUrl(
        Uri.https('www.youtube.com', '/t/terms'),
        mode: LaunchMode.externalApplication,
      );
      if (opened || !context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Impossible d’ouvrir les conditions YouTube.'),
        ),
      );
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Impossible d’ouvrir les conditions YouTube : $error',
            ),
          ),
        );
      }
    }
  }

  Future<void> _openGooglePrivacy(BuildContext context) async {
    try {
      final opened = await launchUrl(
        Uri.https('policies.google.com', '/privacy'),
        mode: LaunchMode.externalApplication,
      );
      if (opened || !context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Impossible d’ouvrir la confidentialité Google.'),
        ),
      );
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Impossible d’ouvrir la politique Google : $error'),
          ),
        );
      }
    }
  }

  Future<void> _setRegionalTrends(BuildContext context, bool enabled) async {
    if (enabled && regionByCode(settings.trendingCountryCode) == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Choisissez d’abord un pays de tendances.'),
        ),
      );
      return;
    }
    if (enabled && !settings.regionalTrendsConsentAccepted) {
      final region = regionByCode(settings.trendingCountryCode)!;
      final accepted = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Activer les tendances régionales ?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Maxei enverra le code pays choisi (${region.name}) au Worker '
                'Maxei, qui interrogera YouTube pour récupérer les vidéos '
                'musicales populaires de cette région. Aucune position GPS '
                'n’est demandée. Les artistes et écoutes de votre bibliothèque '
                'servent uniquement au classement local. Les résultats seront '
                'identifiés comme provenant de YouTube et s’ouvriront dans '
                'YouTube. En activant cette fonction, vous acceptez les '
                'conditions d’utilisation YouTube et reconnaissez que '
                'Maxei utilise les services API YouTube.',
              ),
              TextButton(
                onPressed: () => _openYoutubeTerms(context),
                child: const Text('Conditions d’utilisation YouTube'),
              ),
              TextButton(
                onPressed: () => _openGooglePrivacy(context),
                child: const Text('Confidentialité Google'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Accepter et activer'),
            ),
          ],
        ),
      );
      if (!context.mounted) return;
      if (accepted != true) return;
      settings.regionalTrendsConsentAccepted = true;
    }
    settings.regionalTrendsEnabled = enabled;
    await _save(context);
  }

  void _showHiddenFiles(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => FractionallySizedBox(
        heightFactor: 0.72,
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Fichiers masqués',
                        style: TextStyle(
                          color: ink,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Fermer',
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: hiddenAudioItems.isEmpty
                    ? Center(
                        child: Text(
                          'Aucun fichier masqué',
                          style: TextStyle(color: mutedInk),
                        ),
                      )
                    : ListView.builder(
                        itemCount: hiddenAudioItems.length,
                        itemBuilder: (context, index) {
                          final item = hiddenAudioItems[index];
                          return ListTile(
                            leading: Icon(
                              Icons.music_off_rounded,
                              color: aqua,
                            ),
                            title: Text(
                              item.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              '${item.artist} · ${(item.durationMs! / 1000).toStringAsFixed(1)} s',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: canvas,
    appBar: AppBar(
      title: const Text('Paramètres'),
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
    ),
    body: LiquidBackdrop(
      child: AnimatedBuilder(
        animation: playback,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 32),
          children: [
            const _SectionTitle('APPARENCE'),
            LiquidGlass(
              radius: 20,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Thème'),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: SegmentedButton<AppThemeMode>(
                        segments: const [
                          ButtonSegment(
                            value: AppThemeMode.dark,
                            icon: Icon(Icons.dark_mode_outlined),
                            label: Text('Sombre'),
                          ),
                          ButtonSegment(
                            value: AppThemeMode.light,
                            icon: Icon(Icons.light_mode_outlined),
                            label: Text('Clair'),
                          ),
                        ],
                        selected: {settings.themeMode},
                        onSelectionChanged: (selection) {
                          final mode = selection.first;
                          settings.themeMode = mode;
                          onThemeModeChanged(mode);
                          _save(context);
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 22),
            const _SectionTitle('LECTURE'),
            LiquidGlass(
              radius: 20,
              child: Column(
                children: [
                  ListTile(
                    leading: Icon(Icons.volume_up_outlined, color: aqua),
                    title: const Text('Volume'),
                    subtitle: Slider(
                      value: playback.volume,
                      onChanged: (value) {
                        settings.volume = value;
                        playback.setVolume(value);
                      },
                      onChangeEnd: (_) => _save(context),
                    ),
                    trailing: Text('${(playback.volume * 100).round()}%'),
                  ),
                  ListTile(
                    leading: Icon(Icons.speed_rounded, color: aqua),
                    title: const Text('Vitesse de lecture'),
                    subtitle: Text('${playback.speed.toStringAsFixed(2)}×'),
                    trailing: DropdownButton<double>(
                      value: playback.speed,
                      underline: const SizedBox.shrink(),
                      items: const <double>[0.5, 0.75, 1, 1.25, 1.5, 2]
                          .map(
                            (value) => DropdownMenuItem(
                              value: value,
                              child: Text('$value×'),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value == null) return;
                        settings.speed = value;
                        playback.setSpeed(value);
                        _save(context);
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.shuffle_rounded, color: aqua),
                        const SizedBox(width: 14),
                        const Expanded(child: Text('Lecture aléatoire')),
                        Switch.adaptive(
                          value: playback.shuffleEnabled,
                          onChanged: (value) {
                            settings.shuffle = value;
                            playback.setShuffle(value);
                            _save(context);
                          },
                        ),
                      ],
                    ),
                  ),
                  ListTile(
                    leading: Icon(Icons.repeat_rounded, color: aqua),
                    title: const Text('Répétition'),
                    trailing: DropdownButton<PlaybackRepeatMode>(
                      value: playback.repeatMode,
                      underline: const SizedBox.shrink(),
                      items: PlaybackRepeatMode.values
                          .map(
                            (mode) => DropdownMenuItem(
                              value: mode,
                              child: Text(_repeatLabel(mode)),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value == null) return;
                        settings.repeatMode = value;
                        playback.setRepeatMode(value);
                        _save(context);
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            const _SectionTitle('DÉCOUVERTE MUSICALE'),
            LiquidGlass(
              radius: 20,
              child: Column(
                children: [
                  Material(
                    color: Colors.transparent,
                    child: ListTile(
                      leading: Icon(
                        Icons.person_search_rounded,
                        color: aqua,
                      ),
                      title: const Text('Artistes préférés'),
                      subtitle: Text(
                        '${settings.preferredArtistIds.length} sélectionnés · '
                        'choisir 5 pour personnaliser les suggestions',
                      ),
                      trailing: Icon(
                        Icons.chevron_right_rounded,
                        color: ink,
                      ),
                      onTap: onEditArtists,
                    ),
                  ),
                  if (settings.preferredArtistIds.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final id in settings.preferredArtistIds)
                            if (artistById(id) case final artist?)
                              Chip(
                                avatar: PixelArtistAvatar(
                                  artistId: id,
                                  size: 28,
                                ),
                                label: Text(artist.name),
                              ),
                        ],
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: DropdownButtonFormField<String>(
                      isExpanded: true,
                      initialValue: regionByCode(settings.trendingCountryCode)
                          ?.code,
                      decoration: const InputDecoration(
                        labelText: 'Pays des tendances',
                        helperText:
                            'Choisissez votre région de référence, '
                            'indépendamment de votre emplacement.',
                      ),
                      items: [
                        for (final region in musicRegions)
                          DropdownMenuItem(
                            value: region.code,
                            child: Text(region.name),
                          ),
                      ],
                      onChanged: (code) {
                        if (code == null) return;
                        settings.trendingCountryCode = code;
                        _save(context);
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                    child: Row(
                      children: [
                        Icon(Icons.public_rounded, color: aqua),
                        const SizedBox(width: 14),
                        const Expanded(child: Text('Tendances régionales')),
                        Switch.adaptive(
                          value: settings.regionalTrendsEnabled,
                          onChanged: (value) =>
                              _setRegionalTrends(context, value),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.fromLTRB(16, 0, 16, 14),
                    child: Text(
                      'Désactivées par défaut. Aucun GPS n’est utilisé. '
                      'Les résultats affichent leur source YouTube.',
                      style: TextStyle(color: mutedInk, fontSize: 11),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            const _SectionTitle('VOTRE MUSIQUE'),
            LiquidGlass(
              radius: 20,
              child: GestureDetector(
                onTap: onOpenRecap,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 13,
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.auto_awesome_rounded, color: aqua),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [const Text('Récapitulatif musical')],
                        ),
                      ),
                      Icon(Icons.chevron_right_rounded, color: ink),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 22),
            const _SectionTitle('BIBLIOTHÈQUE'),
            LiquidGlass(
              radius: 20,
              child: Material(
                color: Colors.transparent,
                child: ListTile(
                  leading: Icon(
                    Icons.visibility_off_outlined,
                    color: aqua,
                  ),
                  title: const Text('Fichiers masqués'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${hiddenAudioItems.length}',
                        style: TextStyle(color: mutedInk),
                      ),
                      Icon(Icons.chevron_right_rounded, color: ink),
                    ],
                  ),
                  onTap: () => _showHiddenFiles(context),
                ),
              ),
            ),
            const SizedBox(height: 22),
            const _SectionTitle('BIBLIOTHÈQUE ET TÉLÉCHARGEMENTS'),
            LiquidGlass(
              radius: 20,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.download_for_offline_outlined,
                      color: aqua,
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [Text('Confirmer les téléchargements')],
                      ),
                    ),
                    Switch.adaptive(
                      value: settings.confirmDownloads,
                      onChanged: (value) {
                        settings.confirmDownloads = value;
                        _save(context);
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.label);

  final String label;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
    child: Text(
      label,
      style: TextStyle(
        color: aqua,
        fontSize: 10,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.4,
      ),
    ),
  );
}
