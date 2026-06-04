import 'package:cloud_firestore/cloud_firestore.dart';

class DictationSession {
  const DictationSession({
    required this.id,
    required this.userId,
    required this.youtubeUrl,
    required this.videoTitle,
    required this.totalSegments,
    required this.currentSegmentIndex,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String userId;
  final String youtubeUrl;
  final String videoTitle;
  final int totalSegments;
  final int currentSegmentIndex;
  final DateTime createdAt;
  final DateTime updatedAt;

  DictationSession copyWith({
    String? id,
    String? userId,
    String? youtubeUrl,
    String? videoTitle,
    int? totalSegments,
    int? currentSegmentIndex,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return DictationSession(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      youtubeUrl: youtubeUrl ?? this.youtubeUrl,
      videoTitle: videoTitle ?? this.videoTitle,
      totalSegments: totalSegments ?? this.totalSegments,
      currentSegmentIndex: currentSegmentIndex ?? this.currentSegmentIndex,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory DictationSession.fromJson(Map<String, dynamic> json) {
    return DictationSession(
      id: json['id'] as String? ?? '',
      userId: json['userId'] as String? ?? '',
      youtubeUrl: json['youtubeUrl'] as String? ?? '',
      videoTitle: json['videoTitle'] as String? ?? '',
      totalSegments: (json['totalSegments'] as num?)?.toInt() ?? 0,
      currentSegmentIndex: (json['currentSegmentIndex'] as num?)?.toInt() ?? 0,
      createdAt: _readDate(json['createdAt']),
      updatedAt: _readDate(json['updatedAt']),
    );
  }

  factory DictationSession.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    return DictationSession.fromJson({...?doc.data(), 'id': doc.id});
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'youtubeUrl': youtubeUrl,
      'videoTitle': videoTitle,
      'totalSegments': totalSegments,
      'currentSegmentIndex': currentSegmentIndex,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'userId': userId,
      'youtubeUrl': youtubeUrl,
      'videoTitle': videoTitle,
      'totalSegments': totalSegments,
      'currentSegmentIndex': currentSegmentIndex,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  static DateTime _readDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
    return DateTime.now();
  }
}
