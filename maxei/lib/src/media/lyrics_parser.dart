class LyricLine {
  const LyricLine({required this.text, this.at});

  final String text;
  final Duration? at;
}

final _timestampPattern = RegExp(r'\[(\d{2}):(\d{2})(?:[.:](\d{1,3}))?\]');

List<LyricLine> parseLyrics(String lyrics) {
  final lines = <LyricLine>[];
  for (final rawLine in lyrics.split(RegExp(r'\r?\n'))) {
    final timestamps = _timestampPattern.allMatches(rawLine).toList();
    final text = rawLine.replaceAll(_timestampPattern, '').trim();
    if (timestamps.isEmpty) {
      if (text.isNotEmpty) lines.add(LyricLine(text: text));
      continue;
    }

    for (final match in timestamps) {
      final minutes = int.parse(match.group(1)!);
      final seconds = int.parse(match.group(2)!);
      final fraction = (match.group(3) ?? '').padRight(3, '0');
      final milliseconds = fraction.isEmpty ? 0 : int.parse(fraction);
      lines.add(
        LyricLine(
          text: text,
          at: Duration(
            minutes: minutes,
            seconds: seconds,
            milliseconds: milliseconds,
          ),
        ),
      );
    }
  }
  lines.sort(
    (a, b) => (a.at ?? Duration.zero).compareTo(b.at ?? Duration.zero),
  );
  return lines;
}
