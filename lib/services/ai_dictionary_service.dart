import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

import '../models/vocabulary_item.dart';

class AiDictionaryService {
  const AiDictionaryService({http.Client? client}) : _client = client;

  final http.Client? _client;

  Future<VocabularyItem> lookupWord({
    required String word,
    String sourceContext = '',
  }) async {
    final trimmedWord = word.trim();
    if (trimmedWord.isEmpty) {
      throw Exception('Please enter an English word or phrase.');
    }

    final apiKey = dotenv.maybeGet('GEMINI_API_KEY');
    if (apiKey == null || apiKey.isEmpty || apiKey == 'your_api_key_here') {
      throw Exception('Missing GEMINI_API_KEY. Please add it to .env.');
    }

    final uri = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=$apiKey',
    );
    final client = _client ?? http.Client();

    try {
      final response = await client
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'contents': [
                {
                  'parts': [
                    {
                      'text': _prompt(
                        word: trimmedWord,
                        sourceContext: sourceContext.trim(),
                      ),
                    },
                  ],
                },
              ],
              'generationConfig': {
                'temperature': 0.2,
                'responseMimeType': 'application/json',
              },
            }),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('Gemini API error. Please try again later.');
      }

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final text =
          decoded['candidates']?[0]?['content']?['parts']?[0]?['text']
              as String?;
      if (text == null || text.trim().isEmpty) {
        throw Exception('AI did not return a valid dictionary result.');
      }

      final json = _extractJson(text);
      final definitions = _readDefinitions(json['definitions']);
      final now = DateTime.now();
      final meaningVi = _readString(json['meaningVi']);
      final partOfSpeech = _readString(json['partOfSpeech']);

      return VocabularyItem(
        id: '',
        userId: '',
        word: _readString(json['word'], fallback: trimmedWord),
        meaningVi: meaningVi,
        phonetic: _readString(json['phonetic']),
        partOfSpeech: partOfSpeech,
        exampleEn: _readString(json['exampleEn']),
        exampleVi: _readString(json['exampleVi']),
        sourceContext: sourceContext.trim(),
        definitions:
            definitions.isNotEmpty
                ? definitions
                : [
                  if (meaningVi.isNotEmpty || partOfSpeech.isNotEmpty)
                    VocabularyDefinition(
                      partOfSpeech: partOfSpeech,
                      meaningVi: meaningVi,
                    ),
                ],
        createdAt: now,
        updatedAt: now,
      );
    } on FormatException {
      throw Exception('AI response is not valid JSON. Please try again.');
    } on http.ClientException {
      throw Exception('Cannot connect to Gemini. Please check your network.');
    } on Exception catch (error) {
      final message = error.toString().replaceFirst('Exception: ', '');
      throw Exception(message);
    } finally {
      if (_client == null) client.close();
    }
  }

  Map<String, dynamic> _extractJson(String text) {
    final cleaned =
        text
            .replaceAll('```json', '')
            .replaceAll('```JSON', '')
            .replaceAll('```', '')
            .trim();

    try {
      return jsonDecode(cleaned) as Map<String, dynamic>;
    } catch (_) {
      final start = cleaned.indexOf('{');
      final end = cleaned.lastIndexOf('}');
      if (start == -1 || end == -1 || end <= start) {
        throw const FormatException('Missing JSON object.');
      }
      return jsonDecode(cleaned.substring(start, end + 1))
          as Map<String, dynamic>;
    }
  }

  List<VocabularyDefinition> _readDefinitions(dynamic value) {
    if (value is! List) return const [];
    return value
        .whereType<Map>()
        .map(
          (definition) => VocabularyDefinition.fromJson(
            definition.map((key, value) => MapEntry(key.toString(), value)),
          ),
        )
        .where(
          (definition) =>
              definition.partOfSpeech.trim().isNotEmpty ||
              definition.meaningVi.trim().isNotEmpty,
        )
        .take(5)
        .toList();
  }

  String _readString(dynamic value, {String fallback = ''}) {
    if (value is String && value.trim().isNotEmpty) return value.trim();
    return fallback;
  }

  String _prompt({required String word, required String sourceContext}) {
    return '''
You are an English-Vietnamese dictionary assistant for a vocabulary learning app.

Analyze this English word or phrase and return only valid JSON. Do not return markdown.

Input word/phrase: "$word"
Source context: "$sourceContext"

JSON structure:
{
"word": "normalized English word or phrase",
"meaningVi": "short Vietnamese translation",
"phonetic": "IPA pronunciation if available",
"partOfSpeech": "noun/verb/adjective/adverb/interjection/phrase/etc",
"exampleEn": "simple English example sentence",
"exampleVi": "Vietnamese translation of the example",
"definitions": [
{
"partOfSpeech": "part of speech",
"meaningVi": "Vietnamese meaning or definition"
}
]
}

Rules:
- meaningVi and exampleVi must be Vietnamese.
- Keep definitions concise.
- If the input is a phrase, partOfSpeech can be "phrase".
- Return 1 to 5 definitions.
- Return only JSON.
''';
  }
}
