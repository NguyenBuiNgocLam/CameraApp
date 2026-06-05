import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

import '../models/dictation_segment.dart';
import '../utils/youtube_utils.dart';

class DictationTranscriptResult {
  const DictationTranscriptResult({
    required this.videoTitle,
    required this.segments,
  });

  final String videoTitle;
  final List<DictationSegment> segments;
}

class DictationService {
  DictationService({http.Client? client, String? baseUrl})
    : _client = client ?? http.Client(),
      baseUrl = baseUrl ?? _resolveBaseUrl();

  final http.Client _client;
  final String baseUrl;

  Future<DictationTranscriptResult> fetchTranscript(String youtubeUrl) async {
    final trimmedUrl = youtubeUrl.trim();
    if (!isValidYouTubeUrl(trimmedUrl)) {
      throw Exception('Invalid YouTube URL');
    }

    final uri = Uri.parse(
      '${baseUrl.replaceFirst(RegExp(r'/$'), '')}/api/transcript',
    );

    try {
      final response = await _client
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'youtubeUrl': trimmedUrl}),
          )
          .timeout(const Duration(seconds: 25));

      final body = _decodeBody(response.body);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception(
          body['error'] as String? ??
              'Cannot fetch transcript. Please try another video.',
        );
      }

      final rawSegments = body['segments'];
      if (rawSegments is! List) {
        throw Exception('Transcript response is not valid.');
      }

      final segments =
          rawSegments
              .whereType<Map<String, dynamic>>()
              .map(DictationSegment.fromJson)
              .where((segment) => segment.text.trim().isNotEmpty)
              .toList();

      if (segments.isEmpty) {
        throw Exception(
          'This video does not have an available transcript/caption.',
        );
      }

      return DictationTranscriptResult(
        videoTitle: body['videoTitle'] as String? ?? 'YouTube video',
        segments: segments,
      );
    } on TimeoutException {
      throw Exception(
        'Backend took too long to respond. Please check it is running.',
      );
    } on SocketException {
      throw Exception(
        'Cannot connect to dictation backend. Start the backend and check the base URL.',
      );
    } on FormatException {
      throw Exception('Backend returned invalid data. Please try again.');
    }
  }

  Map<String, dynamic> _decodeBody(String body) {
    final decoded = jsonDecode(body);
    if (decoded is Map<String, dynamic>) return decoded;
    throw const FormatException('Expected JSON object.');
  }

  static String _resolveBaseUrl() {
    const dartDefineUrl = String.fromEnvironment('DICTATION_API_BASE_URL');
    if (dartDefineUrl.trim().isNotEmpty) return dartDefineUrl.trim();

    final envUrl = dotenv.env['DICTATION_API_BASE_URL'] ?? '';
    if (envUrl.trim().isNotEmpty) return envUrl.trim();

    return 'http://10.0.2.2:4000';
  }
}
