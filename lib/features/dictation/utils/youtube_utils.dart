String? extractYoutubeVideoId(String url) {
  final value = url.trim();
  if (value.isEmpty) return null;

  final rawId = _normalizeVideoId(value);
  if (rawId != null) return rawId;

  final uri = Uri.tryParse(value);
  if (uri == null || uri.host.isEmpty) return null;

  final host = uri.host.toLowerCase().replaceFirst('www.', '');
  if (host == 'youtu.be') {
    return _normalizeVideoId(
      uri.pathSegments.isEmpty ? null : uri.pathSegments.first,
    );
  }

  if (host != 'youtube.com' && host != 'm.youtube.com') return null;

  final watchId = uri.queryParameters['v'];
  if (watchId != null) return _normalizeVideoId(watchId);

  if (uri.pathSegments.length >= 2) {
    final prefix = uri.pathSegments.first;
    if (prefix == 'shorts' || prefix == 'embed' || prefix == 'live') {
      return _normalizeVideoId(uri.pathSegments[1]);
    }
  }

  return null;
}

bool isValidYouTubeUrl(String url) {
  return extractYoutubeVideoId(url) != null;
}

String requireYoutubeVideoId(String url) {
  final videoId = extractYoutubeVideoId(url);
  if (videoId == null) {
    throw Exception('Invalid YouTube URL. Cannot get video id.');
  }
  return videoId;
}

String? _normalizeVideoId(String? value) {
  final id = value?.trim();
  if (id == null || id.isEmpty) return null;
  return RegExp(r'^[a-zA-Z0-9_-]{11}$').hasMatch(id) ? id : null;
}
