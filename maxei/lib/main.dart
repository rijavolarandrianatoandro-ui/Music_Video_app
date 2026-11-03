import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:just_audio_background/just_audio_background.dart';

import 'src/maxei_app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const _StartupGate());
}

class _StartupGate extends StatefulWidget {
  const _StartupGate();

  @override
  State<_StartupGate> createState() => _StartupGateState();
}

class _StartupGateState extends State<_StartupGate> {
  String? _warning;

  @override
  void initState() {
    super.initState();
    unawaited(_initializeAudioService());
  }

  Future<void> _initializeAudioService() async {
    if (!kIsWeb &&
        const {
          TargetPlatform.android,
          TargetPlatform.iOS,
          TargetPlatform.macOS,
        }.contains(defaultTargetPlatform)) {
      try {
        await JustAudioBackground.init(
          androidNotificationChannelId: 'app.maxei.audio',
          androidNotificationChannelName: 'Lecture audio',
          androidNotificationChannelDescription: 'Commandes du lecteur Maxei',
          androidNotificationOngoing: true,
        ).timeout(const Duration(seconds: 10));
      } catch (error, stackTrace) {
        debugPrint('Initialisation du service audio impossible: $error');
        debugPrintStack(stackTrace: stackTrace);
        _warning =
            'Le service audio en arrière-plan n’a pas pu démarrer : $error';
      }
    }

    if (mounted && _warning != null) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) => MaxeiApp(startupWarning: _warning);
}
