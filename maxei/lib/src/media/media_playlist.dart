class MediaPlaylist {
  MediaPlaylist(this.name)
    : id = DateTime.now().microsecondsSinceEpoch.toString(),
      mediaIds = [];

  MediaPlaylist.restored({
    required this.id,
    required this.name,
    required List<String> mediaIds,
  }) : mediaIds = List.of(mediaIds);

  final String id;
  String name;
  final List<String> mediaIds;

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'mediaIds': mediaIds,
  };

  factory MediaPlaylist.fromJson(Map<String, dynamic> json) =>
      MediaPlaylist.restored(
        id: json['id'] as String,
        name: json['name'] as String,
        mediaIds: (json['mediaIds'] as List<dynamic>).cast<String>(),
      );
}
