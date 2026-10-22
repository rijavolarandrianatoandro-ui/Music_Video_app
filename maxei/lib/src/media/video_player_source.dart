import 'package:video_player/video_player.dart';

import 'video_player_source_stub.dart'
    if (dart.library.io) 'video_player_source_io.dart'
    as implementation;

VideoPlayerController createVideoPlayerController(Uri uri) =>
    implementation.createVideoPlayerController(uri);
