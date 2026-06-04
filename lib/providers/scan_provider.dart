import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

import '../models/detected_object.dart';
import '../models/vocabulary_item.dart';
import '../services/ai_service.dart';

class ScanProvider extends ChangeNotifier {
  ScanProvider(this._aiService);

  final AiService _aiService;
  final ImagePicker _picker = ImagePicker();
  static const _uuid = Uuid();

  File? selectedImage;
  VocabularyItem? result;
  List<DetectedObject> detections = [];
  int selectedDetectionIndex = 0;
  bool isAnalyzing = false;
  String? errorMessage;

  Future<void> takePhoto() async {
    await _pickImage(ImageSource.camera);
  }

  Future<void> pickFromGallery() async {
    await _pickImage(ImageSource.gallery);
  }

  Future<bool> analyze(String userId) async {
    if (selectedImage == null) {
      errorMessage = 'Please select an image first.';
      notifyListeners();
      return false;
    }

    isAnalyzing = true;
    errorMessage = null;
    notifyListeners();
    try {
      final analysis = await _aiService.analyzeImage(
        imageFile: selectedImage!,
        userId: userId,
      );
      result = analysis.item;
      detections = analysis.objects;
      selectedDetectionIndex = 0;
      if (detections.isNotEmpty) {
        selectDetection(0, userId: userId, notify: false);
      }
      isAnalyzing = false;
      notifyListeners();
      return true;
    } catch (error) {
      errorMessage = error.toString().replaceFirst('Exception: ', '');
      isAnalyzing = false;
      notifyListeners();
      return false;
    }
  }

  void selectDetection(
    int index, {
    required String userId,
    bool notify = true,
  }) {
    if (index < 0 || index >= detections.length) return;
    selectedDetectionIndex = index;
    result = detections[index].toVocabularyItem(
      id: _uuid.v4(),
      userId: userId,
      imagePath: selectedImage?.path,
    );
    if (notify) notifyListeners();
  }

  void toggleResultFavorite() {
    final current = result;
    if (current == null) return;
    result = current.copyWith(isFavorite: !current.isFavorite);
    notifyListeners();
  }

  void clear() {
    selectedImage = null;
    result = null;
    detections = [];
    selectedDetectionIndex = 0;
    errorMessage = null;
    isAnalyzing = false;
    notifyListeners();
  }

  Future<void> _pickImage(ImageSource source) async {
    errorMessage = null;
    final image = await _picker.pickImage(
      source: source,
      imageQuality: 82,
      maxWidth: 1600,
    );
    if (image == null) return;
    selectedImage = File(image.path);
    result = null;
    detections = [];
    selectedDetectionIndex = 0;
    notifyListeners();
  }
}
