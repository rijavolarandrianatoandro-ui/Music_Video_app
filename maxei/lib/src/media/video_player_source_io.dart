import 'dart:io';

import 'package:video_player/video_player.dart';

VideoPlayerController createVideoPlayerController(Uri uri) =>
    uri.scheme == 'file'
    ? VideoPlayerController.file(File.fromUri(uri))
    : VideoPlayerController.networkUrl(uri);
