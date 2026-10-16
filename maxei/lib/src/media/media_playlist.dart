class MediaPlaylist {
  MediaPlaylist(this.name)
    : id = DateTime.now().microsecondsSinceEpoch.toString();

  final String id;
  String name;
  final List<String> mediaIds = [];
}
