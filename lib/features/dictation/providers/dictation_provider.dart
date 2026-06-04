import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/dictation_segment.dart';
import '../models/dictation_session.dart';
import '../services/dictation_firestore_service.dart';
import '../services/dictation_service.dart';
import '../utils/dictation_text_checker.dart';
import '../utils/youtube_utils.dart';

class DictationProvider extends ChangeNotifier {
  DictationProvider({
    required DictationService dictationService,
    required DictationFirestoreService firestoreService,
  }) : _dictationService = dictationService,
       _firestoreService = firestoreService;

  final DictationService _dictationService;
  final DictationFirestoreService _firestoreService;

  bool isLoading = false;
  String? errorMessage;
  String? saveErrorMessage;
  String? videoTitle;
  String? youtubeUrl;
  String? videoId;
  DictationSession? currentSession;
  String? currentSessionId;
  List<DictationSession> recentSessions = [];
  List<DictationSegment> segments = [];
  int currentIndex = 0;
  bool isSaving = false;
  bool isLoadingSessions = false;
  bool isPlaying = false;
  double playbackSpeed = 1;
  bool showFirstLetters = false;
  bool showAllAnswer = false;
  bool hideTranslation = true;
  bool autoNext = false;
  Set<int> revealedWordIndexes = {};
  String? checkMessage;
  bool isLastCheckCorrect = false;
  DictationCheckResult? currentCheckResult;
  Map<int, bool> completedSegments = {};
  Map<int, String> userInputs = {};

  DictationSegment? get currentSegment {
    if (segments.isEmpty) return null;
    if (currentIndex < 0 || currentIndex >= segments.length) return null;
    return segments[currentIndex];
  }

  String _currentUserId() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || uid.isEmpty) {
      throw Exception('Please login before saving dictation progress.');
    }
    return uid;
  }

  void updateYoutubeUrl(String value) {
    setYoutubeUrl(value);
  }

  void setYoutubeUrl(String url) {
    youtubeUrl = url;
    videoId = extractYoutubeVideoId(url);
    if (errorMessage != null) errorMessage = null;
    notifyListeners();
  }

  void setVideoId(String videoId) {
    this.videoId = videoId;
    notifyListeners();
  }

  Future<bool> fetchTranscript() async {
    final trimmedUrl = youtubeUrl?.trim() ?? '';
    if (trimmedUrl.isEmpty) {
      errorMessage = 'Please enter a YouTube URL';
      notifyListeners();
      return false;
    }

    final parsedVideoId = extractYoutubeVideoId(trimmedUrl);
    if (parsedVideoId == null) {
      errorMessage = 'Invalid YouTube URL';
      notifyListeners();
      return false;
    }

    isLoading = true;
    errorMessage = null;
    saveErrorMessage = null;
    notifyListeners();

    try {
      final result = await _dictationService.fetchTranscript(trimmedUrl);
      videoId = parsedVideoId;
      videoTitle = result.videoTitle;
      segments = result.segments;
      currentIndex = 0;
      _hydratePracticeMaps();
      _resetSegmentUi();
      isLoading = false;
      notifyListeners();
      return true;
    } catch (error) {
      errorMessage = error.toString().replaceFirst('Exception: ', '');
      isLoading = false;
      notifyListeners();
      return false;
    }
  }

  void clearError() {
    errorMessage = null;
    notifyListeners();
  }

  void reset() {
    isLoading = false;
    errorMessage = null;
    saveErrorMessage = null;
    videoTitle = null;
    youtubeUrl = null;
    videoId = null;
    currentSession = null;
    currentSessionId = null;
    segments = [];
    currentIndex = 0;
    isPlaying = false;
    playbackSpeed = 1;
    showFirstLetters = false;
    showAllAnswer = false;
    hideTranslation = true;
    autoNext = false;
    revealedWordIndexes = {};
    checkMessage = null;
    isLastCheckCorrect = false;
    currentCheckResult = null;
    completedSegments = {};
    userInputs = {};
    notifyListeners();
  }

  void startPractice(List<DictationSegment> segments, String videoTitle) {
    final url = youtubeUrl?.trim() ?? '';
    if (videoId == null && url.isNotEmpty) {
      videoId = extractYoutubeVideoId(url);
    }
    this.segments = [...segments];
    this.videoTitle = videoTitle;
    currentIndex = 0;
    _hydratePracticeMaps();
    _resetSegmentUi();
    notifyListeners();
  }

  Future<bool> createAndStartSession({
    required String youtubeUrl,
    required String videoTitle,
    required List<DictationSegment> segments,
  }) async {
    if (segments.isEmpty) {
      saveErrorMessage = 'No transcript segments to practice.';
      notifyListeners();
      return false;
    }

    isSaving = true;
    saveErrorMessage = null;
    notifyListeners();

    try {
      final userId = _currentUserId();
      final sessionId = await _firestoreService.createSession(
        userId: userId,
        youtubeUrl: youtubeUrl,
        videoTitle: videoTitle,
        segments: segments,
      );
      final now = DateTime.now();
      currentSessionId = sessionId;
      currentSession = DictationSession(
        id: sessionId,
        userId: userId,
        youtubeUrl: youtubeUrl,
        videoTitle: videoTitle,
        totalSegments: segments.length,
        currentSegmentIndex: 0,
        createdAt: now,
        updatedAt: now,
      );
      this.youtubeUrl = youtubeUrl;
      videoId = extractYoutubeVideoId(youtubeUrl);
      this.videoTitle = videoTitle;
      this.segments = [...segments];
      currentIndex = 0;
      _hydratePracticeMaps();
      _resetSegmentUi();
      isSaving = false;
      await loadRecentSessions();
      notifyListeners();
      return true;
    } catch (error) {
      saveErrorMessage = error.toString().replaceFirst('Exception: ', '');
      isSaving = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> continueSession(DictationSession session) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      final userId = _currentUserId();
      final loadedSegments = await _firestoreService.getSessionSegments(
        userId: userId,
        sessionId: session.id,
      );
      if (loadedSegments.isEmpty) {
        throw Exception('This dictation session has no saved segments.');
      }

      currentSession = session;
      currentSessionId = session.id;
      youtubeUrl = session.youtubeUrl;
      videoId = extractYoutubeVideoId(session.youtubeUrl);
      videoTitle = session.videoTitle;
      segments = loadedSegments;
      currentIndex = session.currentSegmentIndex.clamp(
        0,
        loadedSegments.length - 1,
      );
      _hydratePracticeMaps();
      _resetSegmentUi();
      isLoading = false;
      notifyListeners();
      return true;
    } catch (error) {
      errorMessage = error.toString().replaceFirst('Exception: ', '');
      isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> saveCurrentProgress() async {
    final sessionId = currentSessionId;
    final segment = currentSegment;
    if (sessionId == null || segment == null) return;

    isSaving = true;
    notifyListeners();
    try {
      final userId = _currentUserId();
      final updatedSegment = segment.copyWith(
        isCompleted: segment.isCompleted || segment.userInput.trim().isNotEmpty,
        updatedAt: DateTime.now(),
      );
      segments =
          segments
              .map(
                (item) => item.id == updatedSegment.id ? updatedSegment : item,
              )
              .toList();

      await Future.wait([
        _firestoreService.updateSegmentInput(
          userId: userId,
          sessionId: sessionId,
          segment: updatedSegment,
        ),
        _firestoreService.updateCurrentSegmentIndex(
          userId: userId,
          sessionId: sessionId,
          currentSegmentIndex: currentIndex,
        ),
      ]);

      currentSession = currentSession?.copyWith(
        currentSegmentIndex: currentIndex,
        updatedAt: DateTime.now(),
      );
      saveErrorMessage = null;
    } catch (error) {
      saveErrorMessage = error.toString().replaceFirst('Exception: ', '');
    }
    isSaving = false;
    notifyListeners();
  }

  Future<void> loadRecentSessions() async {
    isLoadingSessions = true;
    notifyListeners();
    try {
      recentSessions = await _firestoreService.getRecentSessions(
        _currentUserId(),
      );
      errorMessage = null;
    } catch (error) {
      errorMessage = error.toString().replaceFirst('Exception: ', '');
    }
    isLoadingSessions = false;
    notifyListeners();
  }

  Future<void> deleteDictationSession(DictationSession session) async {
    isSaving = true;
    notifyListeners();
    try {
      await _firestoreService.deleteSession(
        userId: _currentUserId(),
        sessionId: session.id,
      );
      recentSessions =
          recentSessions.where((item) => item.id != session.id).toList();
      if (currentSessionId == session.id) {
        currentSession = null;
        currentSessionId = null;
      }
      saveErrorMessage = null;
    } catch (error) {
      saveErrorMessage = error.toString().replaceFirst('Exception: ', '');
    }
    isSaving = false;
    notifyListeners();
  }

  void goToNextSegment() {
    if (segments.isEmpty || currentIndex >= segments.length - 1) return;
    currentIndex++;
    _resetSegmentUi();
    notifyListeners();
  }

  void goToPreviousSegment() {
    if (segments.isEmpty || currentIndex <= 0) return;
    currentIndex--;
    _resetSegmentUi();
    notifyListeners();
  }

  void updateUserInput(String value) {
    final segment = currentSegment;
    if (segment == null) return;
    segments =
        segments
            .map(
              (item) =>
                  item.id == segment.id
                      ? item.copyWith(userInput: value)
                      : item,
            )
            .toList();
    userInputs[currentIndex] = value;
    checkMessage = null;
    isLastCheckCorrect = false;
    _refreshCurrentCheckResult();
    notifyListeners();
  }

  Future<bool> checkAndGoNext() async {
    final segment = currentSegment;
    if (segment == null) return false;

    _refreshCurrentCheckResult();
    final input = segment.userInput.trim();
    if (input.isEmpty) {
      checkMessage = 'Please type what you hear.';
      isLastCheckCorrect = false;
      notifyListeners();
      return false;
    }

    final result = currentCheckResult;
    if (result == null) return false;

    if (!result.isCorrect) {
      checkMessage =
          'Not correct yet. Try again. Correct words: '
          '${result.correctWords}/${result.totalWords}';
      isLastCheckCorrect = false;
      notifyListeners();
      return false;
    }

    checkMessage = 'Correct!';
    isLastCheckCorrect = true;
    completedSegments[currentIndex] = true;
    userInputs[currentIndex] = input;
    segments =
        segments
            .map(
              (item) =>
                  item.id == segment.id
                      ? item.copyWith(
                        isCompleted: true,
                        updatedAt: DateTime.now(),
                      )
                      : item,
            )
            .toList();

    await saveCurrentProgress();

    if (currentIndex >= segments.length - 1) {
      finishPractice();
      return true;
    }

    currentIndex++;
    _resetSegmentUi(clearCheckMessage: false);
    notifyListeners();
    return true;
  }

  void togglePlayPause() {
    isPlaying = !isPlaying;
    notifyListeners();
  }

  void replaySegment() {
    replayCurrentSegment();
  }

  void replayCurrentSegment() {
    isPlaying = true;
    notifyListeners();
  }

  void changePlaybackSpeed(double speed) {
    playbackSpeed = speed;
    notifyListeners();
  }

  void toggleFirstLetters() {
    showFirstLetters = !showFirstLetters;
    notifyListeners();
  }

  void revealNextWord() {
    final words = _currentWords();
    if (words.isEmpty) return;
    for (var index = 0; index < words.length; index++) {
      if (!revealedWordIndexes.contains(index)) {
        revealedWordIndexes = {...revealedWordIndexes, index};
        notifyListeners();
        return;
      }
    }
  }

  void showAllWords() {
    showAllAnswer = true;
    revealedWordIndexes = {
      for (var index = 0; index < _currentWords().length; index++) index,
    };
    notifyListeners();
  }

  void hideAllWords() {
    showAllAnswer = false;
    showFirstLetters = false;
    revealedWordIndexes = {};
    notifyListeners();
  }

  void toggleAutoNext() {
    autoNext = !autoNext;
    notifyListeners();
  }

  void toggleTranslation() {
    hideTranslation = !hideTranslation;
    notifyListeners();
  }

  bool finishPractice() {
    isPlaying = false;
    notifyListeners();
    return true;
  }

  void _resetSegmentUi({bool clearCheckMessage = true}) {
    isPlaying = false;
    showFirstLetters = false;
    showAllAnswer = false;
    revealedWordIndexes = {};
    if (clearCheckMessage) {
      checkMessage = null;
      isLastCheckCorrect = false;
    }
    _refreshCurrentCheckResult();
  }

  List<String> _currentWords() {
    return currentSegment?.text.split(RegExp(r'\s+')).where((word) {
          return word.trim().isNotEmpty;
        }).toList() ??
        [];
  }

  void _hydratePracticeMaps() {
    userInputs = {
      for (final segment in segments) segment.index: segment.userInput,
    };
    completedSegments = {
      for (final segment in segments) segment.index: segment.isCompleted,
    };
    _refreshCurrentCheckResult();
  }

  void _refreshCurrentCheckResult() {
    final segment = currentSegment;
    if (segment == null) {
      currentCheckResult = null;
      return;
    }

    currentCheckResult = DictationTextChecker.check(
      userInput: segment.userInput,
      answer: segment.text,
    );
  }
}
