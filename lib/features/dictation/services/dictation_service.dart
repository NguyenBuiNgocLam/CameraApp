import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

import '../../../services/auth_token_service.dart';
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
  DictationService({
    http.Client? client,
    AuthTokenService? authTokenService,
    String? baseUrl,
  }) : _client = client ?? http.Client(),
       _authTokenService = authTokenService ?? const AuthTokenService(),
       baseUrl = baseUrl ?? _resolveBaseUrl();

  final http.Client _client;
  final AuthTokenService _authTokenService;
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
      final token = await _authTokenService.requireIdToken();
      var response = await _postTranscript(
        uri: uri,
        youtubeUrl: trimmedUrl,
        token: token,
      );

      if (response.statusCode == 401) {
        final freshToken = await _authTokenService.getFreshIdToken();
        if (freshToken == null || freshToken.trim().isEmpty) {
          throw Exception(
            'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.',
          );
        }
        response = await _postTranscript(
          uri: uri,
          youtubeUrl: trimmedUrl,
          token: freshToken,
        );
      }

      final body = _decodeBody(response.body);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        if (response.statusCode == 401 || response.statusCode == 403) {
          throw Exception(
            'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.',
          );
        }
        if (response.statusCode == 500) {
          throw Exception('Server error. Please try again later.');
        }
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
      throw Exception('Cannot connect to backend server.');
    } on SocketException {
      throw Exception('Cannot connect to backend server.');
    } on http.ClientException {
      throw Exception('Cannot connect to backend server.');
    } on FormatException {
      throw Exception('Backend returned invalid data. Please try again.');
    }
  }

  Future<http.Response> _postTranscript({
    required Uri uri,
    required String youtubeUrl,
    required String token,
  }) {
    return _client
        .post(
          uri,
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode({'youtubeUrl': youtubeUrl}),
        )
        .timeout(const Duration(seconds: 25));
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
