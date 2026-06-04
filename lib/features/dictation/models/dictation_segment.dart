import 'package:cloud_firestore/cloud_firestore.dart';

class DictationSegment {
  const DictationSegment({
    required this.id,
    required this.index,
    required this.startTime,
    required this.duration,
    required this.text,
    required this.translationVi,
    this.userInput = '',
    this.isSaved = false,
    this.isCompleted = false,
    this.updatedAt,
  });

  final String id;
  final int index;
  final double startTime;
  final double duration;
  final String text;
  final String translationVi;
  final String userInput;
  final bool isSaved;
  final bool isCompleted;
  final DateTime? updatedAt;

  DictationSegment copyWith({
    String? id,
    int? index,
    double? startTime,
    double? duration,
    String? text,
    String? translationVi,
    String? userInput,
    bool? isSaved,
    bool? isCompleted,
    DateTime? updatedAt,
  }) {
    return DictationSegment(
      id: id ?? this.id,
      index: index ?? this.index,
      startTime: startTime ?? this.startTime,
      duration: duration ?? this.duration,
      text: text ?? this.text,
      translationVi: translationVi ?? this.translationVi,
      userInput: userInput ?? this.userInput,
      isSaved: isSaved ?? this.isSaved,
      isCompleted: isCompleted ?? this.isCompleted,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory DictationSegment.fromJson(Map<String, dynamic> json) {
    final index = (json['index'] as num?)?.toInt() ?? 0;
    return DictationSegment(
      id: json['id'] as String? ?? 'segment-$index',
      index: index,
      startTime: (json['startTime'] as num?)?.toDouble() ?? 0,
      duration: (json['duration'] as num?)?.toDouble() ?? 0,
      text: json['text'] as String? ?? '',
      translationVi: json['translationVi'] as String? ?? '',
      userInput: json['userInput'] as String? ?? '',
      isSaved: json['isSaved'] as bool? ?? false,
      isCompleted: json['isCompleted'] as bool? ?? false,
      updatedAt: _readDate(json['updatedAt']),
    );
  }

  factory DictationSegment.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    return DictationSegment.fromJson({...?doc.data(), 'id': doc.id});
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'index': index,
      'startTime': startTime,
      'duration': duration,
      'text': text,
      'translationVi': translationVi,
      'userInput': userInput,
      'isSaved': isSaved,
      'isCompleted': isCompleted,
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'index': index,
      'startTime': startTime,
      'duration': duration,
      'text': text,
      'translationVi': translationVi,
      'userInput': userInput,
      'isSaved': isSaved,
      'isCompleted': isCompleted,
      'updatedAt': Timestamp.fromDate(updatedAt ?? DateTime.now()),
    };
  }

  static DateTime? _readDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }
}
