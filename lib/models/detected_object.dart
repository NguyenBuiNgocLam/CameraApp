import 'vocabulary_item.dart';

class DetectedObject {
  const DetectedObject({
    required this.word,
    required this.meaningVi,
    required this.box2d,
    this.phonetic = '',
    this.partOfSpeech = 'noun',
    this.exampleEn = '',
    this.exampleVi = '',
    this.confidence,
  });

  final String word;
  final String meaningVi;
  final List<int> box2d;
  final String phonetic;
  final String partOfSpeech;
  final String exampleEn;
  final String exampleVi;
  final double? confidence;

  factory DetectedObject.fromJson(Map<String, dynamic> json) {
    final rawBox =
        json['box_2d'] as List<dynamic>? ??
        json['box2d'] as List<dynamic>? ??
        [];
    return DetectedObject(
      word: json['word'] as String? ?? json['label'] as String? ?? 'Object',
      meaningVi: json['meaningVi'] as String? ?? '',
      box2d: rawBox.map((value) => (value as num).round()).toList(),
      phonetic: json['phonetic'] as String? ?? '',
      partOfSpeech: json['partOfSpeech'] as String? ?? 'noun',
      exampleEn: json['exampleEn'] as String? ?? '',
      exampleVi: json['exampleVi'] as String? ?? '',
      confidence: (json['confidence'] as num?)?.toDouble(),
    );
  }

  VocabularyItem toVocabularyItem({
    required String id,
    required String userId,
    required String? imagePath,
  }) {
    final now = DateTime.now();
    return VocabularyItem(
      id: id,
      userId: userId,
      word: word,
      meaningVi: meaningVi,
      phonetic: phonetic,
      partOfSpeech: partOfSpeech,
      exampleEn:
          exampleEn.isEmpty ? 'This is a ${word.toLowerCase()}.' : exampleEn,
      exampleVi: exampleVi,
      imagePath: imagePath,
      confidence: confidence,
      createdAt: now,
      updatedAt: now,
    );
  }
}

class AiAnalysisResult {
  const AiAnalysisResult({required this.item, required this.objects});

  final VocabularyItem item;
  final List<DetectedObject> objects;
}
