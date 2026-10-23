import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:just_audio_background/just_audio_background.dart';

import 'src/maxei_app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!kIsWeb &&
      const {
        TargetPlatform.android,
        TargetPlatform.iOS,
        TargetPlatform.macOS,
      }.contains(defaultTargetPlatform)) {
    await JustAudioBackground.init(
      androidNotificationChannelId: 'app.maxei.audio',
      androidNotificationChannelName: 'Lecture audio',
      androidNotificationChannelDescription: 'Commandes du lecteur Maxei',
      androidNotificationOngoing: true,
    );
  }
  runApp(const MaxeiApp());
}
