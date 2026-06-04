import 'dart:convert';
import 'dart:io';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

import '../models/detected_object.dart';
import '../models/vocabulary_item.dart';

class AiService {
  static const _uuid = Uuid();

  Future<AiAnalysisResult> analyzeImage({
    required File imageFile,
    required String userId,
  }) async {
    final apiKey = dotenv.maybeGet('GEMINI_API_KEY');
    if (apiKey == null || apiKey.isEmpty || apiKey == 'your_api_key_here') {
      throw Exception('Missing GEMINI_API_KEY. Please add it to .env.');
    }

    final imageBytes = await imageFile.readAsBytes();
    final imageBase64 = base64Encode(imageBytes);
    final uri = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=$apiKey',
    );

    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'contents': [
          {
            'parts': [
              {'text': _prompt},
              {
                'inlineData': {
                  'mimeType': _mimeType(imageFile.path),
                  'data': imageBase64,
                },
              },
            ],
          },
        ],
        'generationConfig': {
          'temperature': 0.2,
          'responseMimeType': 'text/plain',
        },
      }),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('AI API error. Please try again later.');
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final text =
        decoded['candidates']?[0]?['content']?['parts']?[0]?['text'] as String?;
    if (text == null || text.trim().isEmpty) {
      throw Exception('AI did not return a valid result.');
    }

    final json = _extractJson(text);
    if (json.containsKey('error')) {
      throw Exception(
        json['error'] as String? ?? 'Cannot identify object clearly.',
      );
    }

    final primary = (json['primary'] as Map<String, dynamic>?) ?? json;
    final objects =
        (json['objects'] as List<dynamic>? ?? [])
            .whereType<Map<String, dynamic>>()
            .map(DetectedObject.fromJson)
            .where((object) => object.box2d.length == 4)
            .where((object) => _isUsefulObject(object.word))
            .toList()
          ..sort((a, b) => _boxArea(b.box2d).compareTo(_boxArea(a.box2d)));
    final visibleObjects = objects.take(8).toList();
    final primaryObject = visibleObjects.firstOrNull;

    final now = DateTime.now();
    final item = VocabularyItem(
      id: _uuid.v4(),
      userId: userId,
      word: primaryObject?.word ?? primary['word'] as String? ?? 'Unknown',
      meaningVi:
          primaryObject?.meaningVi ?? primary['meaningVi'] as String? ?? '',
      phonetic: primaryObject?.phonetic ?? primary['phonetic'] as String? ?? '',
      partOfSpeech:
          primaryObject?.partOfSpeech ??
          primary['partOfSpeech'] as String? ??
          'noun',
      exampleEn:
          primaryObject?.exampleEn ?? primary['exampleEn'] as String? ?? '',
      exampleVi:
          primaryObject?.exampleVi ?? primary['exampleVi'] as String? ?? '',
      imagePath: imageFile.path,
      confidence:
          primaryObject?.confidence ??
          (primary['confidence'] as num?)?.toDouble(),
      createdAt: now,
      updatedAt: now,
    );

    return AiAnalysisResult(
      item: item,
      objects:
          visibleObjects.isEmpty
              ? [
                DetectedObject(
                  word: item.word,
                  meaningVi: item.meaningVi,
                  box2d: const [80, 80, 920, 920],
                  phonetic: item.phonetic,
                  partOfSpeech: item.partOfSpeech,
                  exampleEn: item.exampleEn,
                  exampleVi: item.exampleVi,
                  confidence: item.confidence,
                ),
              ]
              : visibleObjects,
    );
  }

  bool _isUsefulObject(String word) {
    final normalized = word.trim().toLowerCase();
    const noisyLabels = {
      'person',
      'people',
      'human',
      'man',
      'woman',
      'boy',
      'girl',
      'child',
      'face',
      'hair',
      'ear',
      'hand',
      'finger',
      'arm',
      'leg',
      'head',
      'neck',
      'shoulder',
      'body',
      'eye',
      'nose',
      'mouth',
    };
    return !noisyLabels.contains(normalized);
  }

  int _boxArea(List<int> box) {
    if (box.length != 4) return 0;
    final height = (box[2] - box[0]).abs();
    final width = (box[3] - box[1]).abs();
    return height * width;
  }

  Map<String, dynamic> _extractJson(String text) {
    final cleaned = text.replaceAll('```json', '').replaceAll('```', '').trim();
    try {
      return jsonDecode(cleaned) as Map<String, dynamic>;
    } catch (_) {
      final start = cleaned.indexOf('{');
      final end = cleaned.lastIndexOf('}');
      if (start == -1 || end == -1 || end <= start) {
        throw Exception('AI response is not valid JSON.');
      }
      return jsonDecode(cleaned.substring(start, end + 1))
          as Map<String, dynamic>;
    }
  }

  String _mimeType(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    return 'image/jpeg';
  }

  static const _prompt = '''
Analyze this image and detect all clearly visible prominent objects.
Return only valid JSON with this structure:
{
  "primary": {
    "word": "English name of the most important object",
    "meaningVi": "Vietnamese meaning",
    "phonetic": "IPA pronunciation",
    "partOfSpeech": "noun/verb/adjective",
    "exampleEn": "Simple English example sentence",
    "exampleVi": "Vietnamese translation of the example",
    "confidence": 0.0
  },
  "objects": [
    {
      "word": "English object name",
      "meaningVi": "Vietnamese meaning",
      "phonetic": "IPA pronunciation",
      "partOfSpeech": "noun/verb/adjective",
      "exampleEn": "Simple English example sentence",
      "exampleVi": "Vietnamese translation of the example",
      "box_2d": [ymin, xmin, ymax, xmax],
      "confidence": 0.0
    }
  ]
}
The box_2d coordinates must be integers normalized from 0 to 1000, in [ymin, xmin, ymax, xmax] order.
Only include up to 8 clearly visible useful vocabulary objects.
Avoid body parts, people, faces, hair, ears, hands, and vague labels unless there are no other objects.
Prefer concrete objects like table, chair, cup, book, lamp, laptop, bottle, bag, phone, door, window.
Do not guess.
If the image is unclear, return:
{
"error": "Cannot identify object clearly"
}
''';
}
