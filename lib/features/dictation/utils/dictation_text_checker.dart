class WordMatch {
  const WordMatch({
    required this.originalWord,
    required this.normalizedOriginalWord,
    required this.userWord,
    required this.isCorrect,
  });

  final String originalWord;
  final String normalizedOriginalWord;
  final String? userWord;
  final bool isCorrect;
}

class DictationCheckResult {
  const DictationCheckResult({
    required this.isCorrect,
    required this.correctWords,
    required this.totalWords,
    required this.normalizedUserInput,
    required this.normalizedAnswer,
    required this.wordMatches,
  });

  final bool isCorrect;
  final int correctWords;
  final int totalWords;
  final String normalizedUserInput;
  final String normalizedAnswer;
  final List<WordMatch> wordMatches;
}

class DictationTextChecker {
  const DictationTextChecker._();

  static DictationCheckResult check({
    required String userInput,
    required String answer,
  }) {
    final normalizedUserInput = _normalize(userInput);
    final normalizedAnswer = _normalize(answer);

    final userWords =
        normalizedUserInput.isEmpty
            ? <String>[]
            : normalizedUserInput.split(' ');
    final originalAnswerWords =
        answer
            .split(RegExp(r'\s+'))
            .map((word) => word.trim())
            .where((word) => word.isNotEmpty && _normalize(word).isNotEmpty)
            .toList();

    final wordMatches = List<WordMatch>.generate(originalAnswerWords.length, (
      index,
    ) {
      final originalWord = originalAnswerWords[index];
      final normalizedOriginalWord = _normalize(originalWord);
      final userWord = index < userWords.length ? userWords[index] : null;
      final isCorrect =
          normalizedOriginalWord.isNotEmpty &&
          userWord == normalizedOriginalWord;

      return WordMatch(
        originalWord: originalWord,
        normalizedOriginalWord: normalizedOriginalWord,
        userWord: userWord,
        isCorrect: isCorrect,
      );
    });

    final correctWords = wordMatches.where((match) => match.isCorrect).length;

    return DictationCheckResult(
      isCorrect: normalizedUserInput == normalizedAnswer,
      correctWords: correctWords,
      totalWords: originalAnswerWords.length,
      normalizedUserInput: normalizedUserInput,
      normalizedAnswer: normalizedAnswer,
      wordMatches: wordMatches,
    );
  }

  static String _normalize(String text) {
    return text
        .toLowerCase()
        .replaceAll("'", '')
        .replaceAll(RegExp(r'''[^a-z0-9\s]'''), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}
