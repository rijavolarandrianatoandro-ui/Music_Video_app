import 'package:flutter/material.dart';

import '../media/listening_recap.dart';
import '../theme/maxei_theme.dart';
import '../widgets/liquid_surface.dart';

class ListeningRecapScreen extends StatelessWidget {
  const ListeningRecapScreen({super.key, required this.recap});

  final ListeningRecap recap;

  static const _months = [
    'janvier',
    'février',
    'mars',
    'avril',
    'mai',
    'juin',
    'juillet',
    'août',
    'septembre',
    'octobre',
    'novembre',
    'décembre',
  ];

  static String formatDuration(int milliseconds) {
    final minutes = milliseconds ~/ Duration.millisecondsPerMinute;
    if (minutes < 60) return '$minutes min';
    final hours = minutes ~/ 60;
    final remainingMinutes = minutes % 60;
    return remainingMinutes == 0 ? '$hours h' : '$hours h $remainingMinutes';
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: canvas,
    appBar: AppBar(
      title: const Text('Récap musical'),
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
    ),
    body: LiquidBackdrop(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 32),
        children: [
          Text(
            '${_months[recap.start.month - 1].toUpperCase()} ${recap.start.year}',
            style: TextStyle(
              color: aqua,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.8,
            ),
          ),
          const SizedBox(height: 8),
          if (recap.sessions.isEmpty)
            LiquidGlass(
              radius: 22,
              padding: const EdgeInsets.all(18),
              child: Text(
                'Pas encore d’écoutes ce mois-ci.',
                style: TextStyle(color: ink, height: 1.5),
              ),
            ),
          LiquidGlass(
            radius: 25,
            tint: surface,
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.graphic_eq_rounded, color: aqua, size: 26),
                const SizedBox(height: 14),
                Text(
                  formatDuration(recap.totalMilliseconds),
                  style: TextStyle(
                    color: ink,
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'passées à écouter votre musique',
                  style: TextStyle(color: mutedInk, fontSize: 13),
                ),
                const SizedBox(height: 18),
                Wrap(
                  spacing: 9,
                  runSpacing: 9,
                  children: [
                    _StatChip(
                      icon: Icons.play_circle_outline_rounded,
                      label: '${recap.sessions.length} écoutes',
                    ),
                    _StatChip(
                      icon: Icons.music_note_rounded,
                      label: '${recap.uniqueTracks} titres',
                    ),
                    _StatChip(
                      icon: Icons.calendar_month_rounded,
                      label: '${recap.activeDays} jours actifs',
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (recap.topTracks.isNotEmpty) ...[
            const SizedBox(height: 24),
            const _SectionTitle('VOTRE BANDE-SON'),
            const SizedBox(height: 8),
            LiquidGlass(
              radius: 22,
              child: Column(
                children: [
                  for (var index = 0; index < recap.topTracks.length; index++)
                    _TrackRow(track: recap.topTracks[index], rank: index + 1),
                ],
              ),
            ),
          ],
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _HighlightCard(
                  icon: Icons.person_rounded,
                  title: 'Artiste du mois',
                  value: recap.topArtist ?? 'À découvrir',
                  detail: 'Le plus écouté',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _HighlightCard(
                  icon: Icons.local_fire_department_rounded,
                  title: 'Votre série',
                  value: '${recap.longestStreak} jours',
                  detail: 'd’écoute à la suite',
                ),
              ),
            ],
          ),
          if (recap.topFavorite != null) ...[
            const SizedBox(height: 16),
            _HighlightCard(
              icon: Icons.favorite_rounded,
              title: 'Favori le plus écouté',
              value: recap.topFavorite!.title,
              detail: recap.topFavorite!.artist,
              fullWidth: true,
            ),
          ],
          const SizedBox(height: 16),
          _MonthlyComparison(recap: recap),
        ],
      ),
    ),
  );
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
    decoration: BoxDecoration(
      color: ink.withValues(alpha: 0.07),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: aqua),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(color: ink, fontSize: 11)),
      ],
    ),
  );
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) => Text(
    title,
    style: TextStyle(
      color: aqua,
      fontSize: 10,
      fontWeight: FontWeight.w800,
      letterSpacing: 1.5,
    ),
  );
}

class _TrackRow extends StatelessWidget {
  const _TrackRow({required this.track, required this.rank});

  final TrackRecap track;
  final int rank;

  @override
  Widget build(BuildContext context) => ListTile(
    leading: SizedBox(
      width: 35,
      child: Text(
        rank.toString().padLeft(2, '0'),
        textAlign: TextAlign.center,
        style: TextStyle(
          color: aqua,
          fontWeight: FontWeight.w800,
          fontSize: 16,
        ),
      ),
    ),
    title: Text(
      track.title,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(color: ink, fontWeight: FontWeight.w700),
    ),
    subtitle: Text(
      '${track.artist} · ${track.plays} ${track.plays == 1 ? 'lecture' : 'lectures'}',
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(color: mutedInk, fontSize: 11),
    ),
    trailing: track.isFavorite
        ? Icon(Icons.favorite_rounded, size: 17, color: aqua)
        : null,
  );
}

class _HighlightCard extends StatelessWidget {
  const _HighlightCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.detail,
    this.fullWidth = false,
  });

  final IconData icon;
  final String title;
  final String value;
  final String detail;
  final bool fullWidth;

  @override
  Widget build(BuildContext context) {
    final card = LiquidGlass(
      radius: 20,
      padding: const EdgeInsets.all(15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 19, color: aqua),
          const SizedBox(height: 10),
          Text(title, style: TextStyle(color: mutedInk, fontSize: 10)),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: ink,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            detail,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: mutedInk, fontSize: 10),
          ),
        ],
      ),
    );
    return fullWidth ? SizedBox(width: double.infinity, child: card) : card;
  }
}

class _MonthlyComparison extends StatelessWidget {
  const _MonthlyComparison({required this.recap});

  final ListeningRecap recap;

  @override
  Widget build(BuildContext context) {
    final previous = recap.previousMonthMilliseconds;
    final current = recap.totalMilliseconds;
    final change = previous == 0
        ? 0
        : ((current - previous) / previous * 100).round();
    final label = previous == 0
        ? 'Votre prochain récap permettra de comparer vos mois.'
        : change == 0
        ? 'Autant de temps que le mois précédent.'
        : '${change > 0 ? '+' : ''}$change % de temps d’écoute par rapport au mois précédent.';
    return LiquidGlass(
      radius: 20,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Icon(Icons.trending_up_rounded, color: aqua),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(color: ink, fontSize: 12, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}
