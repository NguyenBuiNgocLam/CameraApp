import 'dart:convert';
import 'dart:io';

import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';

import '../../../models/vocabulary_item.dart';

class CsvImportService {
  Future<List<VocabularyItem>?> pickAndParseVocabularyCsv() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['csv'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return null;

    final file = result.files.single;
    final bytes =
        file.bytes ??
        (file.path == null ? null : await File(file.path!).readAsBytes());
    if (bytes == null) {
      throw Exception('Cannot read selected CSV file.');
    }

    return parseVocabularyCsv(utf8.decode(bytes));
  }

  List<VocabularyItem> parseVocabularyCsv(String csvText) {
    if (csvText.trim().isEmpty) {
      throw Exception('CSV file is empty.');
    }

    final rows = const CsvToListConverter(
      shouldParseNumbers: false,
    ).convert(csvText);
    if (rows.length < 2) {
      throw Exception('CSV must include a header row and at least one word.');
    }
    if (rows.length > 501) {
      throw Exception('CSV is too large. Please import up to 500 words.');
    }

    final headers =
        rows.first
            .map((cell) => cell.toString().trim())
            .map(_normalizeHeader)
            .toList();
    final wordIndex = headers.indexOf('word');
    final meaningIndex = headers.indexOf('meaningvi');
    if (wordIndex == -1 || meaningIndex == -1) {
      throw Exception('CSV must include word and meaningVi columns.');
    }

    final items = <VocabularyItem>[];
    final now = DateTime.now();

    for (final row in rows.skip(1)) {
      final word = _readCell(row, wordIndex);
      final meaningVi = _readCell(row, meaningIndex);
      if (word.isEmpty && meaningVi.isEmpty) continue;
      if (word.isEmpty || meaningVi.isEmpty) {
        throw Exception('Each CSV row must include word and meaningVi.');
      }

      final definitions = _readDefinitions(
        _readOptionalCell(row, headers, 'definitions'),
        fallbackPartOfSpeech: _readOptionalCell(row, headers, 'partofspeech'),
        fallbackMeaningVi: meaningVi,
      );
      final imageUrl = _readOptionalCell(row, headers, 'imageurl');
      if (imageUrl.isNotEmpty && !imageUrl.startsWith('https://')) {
        throw Exception('Image URL must start with https://');
      }

      items.add(
        VocabularyItem(
          id: '',
          userId: '',
          word: word,
          meaningVi: meaningVi,
          phonetic: _readOptionalCell(row, headers, 'phonetic'),
          partOfSpeech: _readOptionalCell(row, headers, 'partofspeech'),
          exampleEn: _readOptionalCell(row, headers, 'exampleen'),
          exampleVi: _readOptionalCell(row, headers, 'examplevi'),
          sourceContext: _readOptionalCell(row, headers, 'sourcecontext'),
          imageUrl: imageUrl,
          definitions: definitions,
          createdAt: now,
          updatedAt: now,
        ),
      );
    }

    if (items.isEmpty) {
      throw Exception('CSV does not contain any valid vocabulary rows.');
    }

    return items;
  }

  String _readOptionalCell(
    List<dynamic> row,
    List<String> headers,
    String key,
  ) {
    final index = headers.indexOf(key);
    if (index == -1) return '';
    return _readCell(row, index);
  }

  String _readCell(List<dynamic> row, int index) {
    if (index < 0 || index >= row.length) return '';
    return row[index].toString().trim();
  }

  String _normalizeHeader(String value) {
    return value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
  }

  List<VocabularyDefinition> _readDefinitions(
    String value, {
    required String fallbackPartOfSpeech,
    required String fallbackMeaningVi,
  }) {
    if (value.trim().isEmpty) {
      return [
        VocabularyDefinition(
          partOfSpeech: fallbackPartOfSpeech,
          meaningVi: fallbackMeaningVi,
        ),
      ];
    }

    return value
        .split(';')
        .map((raw) => raw.trim())
        .where((raw) => raw.isNotEmpty)
        .map((raw) {
          final separator = raw.indexOf(':');
          if (separator == -1) {
            return VocabularyDefinition(
              partOfSpeech: fallbackPartOfSpeech,
              meaningVi: raw,
            );
          }
          return VocabularyDefinition(
            partOfSpeech: raw.substring(0, separator).trim(),
            meaningVi: raw.substring(separator + 1).trim(),
          );
        })
        .where((definition) => definition.meaningVi.trim().isNotEmpty)
        .toList();
  }
}
