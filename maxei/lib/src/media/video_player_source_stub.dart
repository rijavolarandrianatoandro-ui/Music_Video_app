import 'package:video_player/video_player.dart';

VideoPlayerController createVideoPlayerController(Uri uri) =>
    VideoPlayerController.networkUrl(uri);
