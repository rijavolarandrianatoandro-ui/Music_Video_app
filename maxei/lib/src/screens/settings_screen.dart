import 'package:flutter/material.dart';

import '../media/app_settings.dart';
import '../media/playback_controller.dart';
import '../theme/maxei_theme.dart';
import '../widgets/liquid_surface.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({
    super.key,
    required this.settings,
    required this.playback,
    required this.onChanged,
  });

  final AppSettings settings;
  final PlaybackController playback;
  final Future<void> Function() onChanged;

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
            const _SectionTitle('LECTURE'),
            LiquidGlass(
              radius: 20,
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.volume_up_outlined, color: aqua),
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
                    leading: const Icon(Icons.speed_rounded, color: aqua),
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
                  SwitchListTile.adaptive(
                    secondary: const Icon(Icons.shuffle_rounded, color: aqua),
                    title: const Text('Lecture aléatoire'),
                    value: playback.shuffleEnabled,
                    onChanged: (value) {
                      settings.shuffle = value;
                      playback.setShuffle(value);
                      _save(context);
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.repeat_rounded, color: aqua),
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
            const _SectionTitle('BIBLIOTHÈQUE ET TÉLÉCHARGEMENTS'),
            LiquidGlass(
              radius: 20,
              child: SwitchListTile.adaptive(
                secondary: const Icon(
                  Icons.download_for_offline_outlined,
                  color: aqua,
                ),
                title: const Text('Confirmer les téléchargements'),
                subtitle: const Text(
                  'Demander une confirmation avant d’enregistrer un média.',
                ),
                value: settings.confirmDownloads,
                onChanged: (value) {
                  settings.confirmDownloads = value;
                  _save(context);
                },
              ),
            ),
            const SizedBox(height: 22),
            const _SectionTitle('À PROPOS DE MAXEI'),
            LiquidGlass(
              radius: 20,
              child: const ListTile(
                leading: Icon(Icons.info_outline_rounded, color: aqua),
                title: Text('Lecteur local, privé par défaut'),
                subtitle: Text(
                  'Vos médias importés restent dans la bibliothèque de cet appareil.',
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
      style: const TextStyle(
        color: aqua,
        fontSize: 10,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.4,
      ),
    ),
  );
}
