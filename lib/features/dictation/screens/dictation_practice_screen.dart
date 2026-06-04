import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

import '../../../app/routes.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/custom_button.dart';
import '../../../core/widgets/empty_state_widget.dart';
import '../../../core/widgets/main_scaffold.dart';
import '../models/dictation_segment.dart';
import '../providers/dictation_provider.dart';
import '../utils/dictation_text_checker.dart';

class DictationPracticeScreen extends StatefulWidget {
  const DictationPracticeScreen({super.key});

  @override
  State<DictationPracticeScreen> createState() =>
      _DictationPracticeScreenState();
}

class _DictationPracticeScreenState extends State<DictationPracticeScreen> {
  final _inputController = TextEditingController();
  YoutubePlayerController? _playerController;
  Timer? _segmentTimer;
  String? _segmentId;
  String? _syncedSegmentId;
  String? _videoId;

  @override
  void dispose() {
    _cancelSegmentTimer();
    _pausePlayer();
    _playerController?.dispose();
    _inputController.dispose();
    super.dispose();
  }

  Future<void> _finishPractice(BuildContext context) async {
    _cancelSegmentTimer();
    _pausePlayer();
    final provider = context.read<DictationProvider>();
    final success = await provider.checkAndGoNext();
    if (!context.mounted) return;
    if (!success) return;
    await showDialog<void>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Practice completed'),
            content: const Text(
              'You finished this dictation practice session.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Stay'),
              ),
              FilledButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pushReplacementNamed(context, AppRoutes.dictation);
                },
                child: const Text('Back Home'),
              ),
            ],
          ),
    );
  }

  void _ensurePlayer(String videoId, DictationSegment segment) {
    if (_videoId == videoId && _playerController != null) return;

    _cancelSegmentTimer();
    _playerController?.dispose();
    _videoId = videoId;
    _syncedSegmentId = null;
    _playerController = YoutubePlayerController(
      initialVideoId: videoId,
      flags: YoutubePlayerFlags(
        autoPlay: false,
        hideControls: true,
        controlsVisibleAtStart: false,
        enableCaption: false,
        startAt: segment.startTime.floor(),
      ),
    );
  }

  void _seekToSegment(
    DictationSegment segment,
    DictationProvider dictation, {
    required bool play,
  }) {
    final controller = _playerController;
    if (controller == null) return;

    _cancelSegmentTimer();
    controller.setPlaybackRate(dictation.playbackSpeed);
    controller.seekTo(
      Duration(milliseconds: (segment.startTime * 1000).round()),
      allowSeekAhead: true,
    );

    if (play) {
      controller.play();
      _startSegmentTimer(segment, dictation, waitForSeek: true);
    } else {
      _pausePlayerAfterSeek();
    }
  }

  void _syncSegmentAfterBuild(
    DictationSegment segment,
    DictationProvider dictation,
  ) {
    if (_syncedSegmentId == segment.id) return;
    _syncedSegmentId = segment.id;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final canAutoPlay =
          dictation.autoNext &&
          dictation.completedSegments[dictation.currentIndex] == true;
      _seekToSegment(segment, dictation, play: canAutoPlay);
      if (canAutoPlay && !dictation.isPlaying) {
        context.read<DictationProvider>().replayCurrentSegment();
      }
    });
  }

  void _startSegmentTimer(
    DictationSegment segment,
    DictationProvider dictation, {
    bool waitForSeek = false,
  }) {
    _cancelSegmentTimer();
    final speed = dictation.playbackSpeed <= 0 ? 1.0 : dictation.playbackSpeed;
    final duration = segment.duration <= 0 ? 5.0 : segment.duration;
    final milliseconds = ((duration / speed) * 1000).round();
    final timerMilliseconds = milliseconds.clamp(500, 60000).toInt();
    final seekDelay =
        waitForSeek ? const Duration(milliseconds: 350) : Duration.zero;
    _segmentTimer = Timer(
      seekDelay + Duration(milliseconds: timerMilliseconds),
      () async {
        if (!mounted) return;
        final provider = context.read<DictationProvider>();

        final currentCompleted =
            provider.completedSegments[provider.currentIndex] == true;
        if (provider.autoNext &&
            currentCompleted &&
            provider.currentIndex < provider.segments.length - 1) {
          await provider.saveCurrentProgress();
          if (!mounted) return;
          provider.goToNextSegment();
          provider.replayCurrentSegment();
          await provider.saveCurrentProgress();
          final nextSegment = provider.currentSegment;
          if (nextSegment != null) {
            _syncedSegmentId = nextSegment.id;
            _seekToSegment(nextSegment, provider, play: true);
          }
        } else {
          _pausePlayer();
          provider.finishPractice();
        }
      },
    );
  }

  void _cancelSegmentTimer() {
    _segmentTimer?.cancel();
    _segmentTimer = null;
  }

  void _pausePlayer() {
    final controller = _playerController;
    if (controller == null) return;
    controller.pause();

    // WebView commands can complete slightly out of order after seekTo().
    // Repeating pause prevents YouTube's internal autoplay-after-seek from
    // continuing past the dictation segment.
    Future<void>.delayed(const Duration(milliseconds: 250), () {
      if (mounted) controller.pause();
    });
    Future<void>.delayed(const Duration(milliseconds: 700), () {
      if (mounted) controller.pause();
    });
  }

  void _pausePlayerAfterSeek() {
    _pausePlayer();
    Future<void>.delayed(const Duration(milliseconds: 350), () {
      if (mounted) _pausePlayer();
    });
  }

  void _togglePlayPause(BuildContext context) {
    final dictation = context.read<DictationProvider>();
    final segment = dictation.currentSegment;
    if (segment == null) return;

    if (dictation.isPlaying) {
      _cancelSegmentTimer();
      _pausePlayer();
      dictation.togglePlayPause();
      return;
    }

    dictation.togglePlayPause();
    _seekToSegment(segment, dictation, play: true);
  }

  void _replayCurrentSegment(BuildContext context) {
    final dictation = context.read<DictationProvider>();
    final segment = dictation.currentSegment;
    if (segment == null) return;

    dictation.replayCurrentSegment();
    _seekToSegment(segment, dictation, play: true);
  }

  Future<void> _goToNextSegment(BuildContext context) async {
    await _checkAndMaybeAdvance(context);
  }

  Future<void> _goToPreviousSegment(BuildContext context) async {
    final dictation = context.read<DictationProvider>();
    if (dictation.currentIndex <= 0) return;

    _cancelSegmentTimer();
    final shouldKeepPlaying = dictation.isPlaying;
    await dictation.saveCurrentProgress();
    if (!context.mounted) return;
    dictation.goToPreviousSegment();
    await dictation.saveCurrentProgress();
    final segment = dictation.currentSegment;
    if (segment == null) return;

    _syncedSegmentId = segment.id;
    if (shouldKeepPlaying) {
      dictation.replayCurrentSegment();
    }
    _seekToSegment(segment, dictation, play: shouldKeepPlaying);
  }

  void _changePlaybackSpeed(BuildContext context, double speed) {
    final dictation = context.read<DictationProvider>();
    dictation.changePlaybackSpeed(speed);
    _playerController?.setPlaybackRate(speed);

    if (dictation.isPlaying) {
      final segment = dictation.currentSegment;
      if (segment != null) _startSegmentTimer(segment, dictation);
    }
  }

  Future<void> _saveSentence(BuildContext context) async {
    await context.read<DictationProvider>().saveCurrentProgress();
    if (!context.mounted) return;
    final error = context.read<DictationProvider>().saveErrorMessage;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(error ?? 'Saved')));
  }

  Future<void> _checkAndMaybeAdvance(BuildContext context) async {
    final dictation = context.read<DictationProvider>();
    final oldIndex = dictation.currentIndex;
    final wasLast = oldIndex >= dictation.segments.length - 1;

    _cancelSegmentTimer();
    _pausePlayer();
    final success = await dictation.checkAndGoNext();
    if (!context.mounted || !success) return;

    if (wasLast) {
      await _finishPracticeDialog(context);
      return;
    }

    final segment = dictation.currentSegment;
    if (segment == null) return;
    _syncedSegmentId = segment.id;
    if (dictation.autoNext) {
      dictation.replayCurrentSegment();
      _seekToSegment(segment, dictation, play: true);
    } else {
      _seekToSegment(segment, dictation, play: false);
    }
  }

  Future<void> _finishPracticeDialog(BuildContext context) async {
    await showDialog<void>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Practice completed'),
            content: const Text(
              'You finished this dictation practice session.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Stay'),
              ),
              FilledButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pushReplacementNamed(context, AppRoutes.dictation);
                },
                child: const Text('Back Home'),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dictation = context.watch<DictationProvider>();
    final segment = dictation.currentSegment;
    final colors = Theme.of(context).colorScheme;
    final videoId = dictation.videoId;

    if (segment == null || videoId == null) {
      return MainScaffold(
        currentIndex: 0,
        appBar: AppBar(title: const Text('Dictation Practice')),
        child: const EmptyStateWidget(
          title: 'No segments ready',
          message: 'Get a YouTube transcript before starting practice.',
          icon: Icons.subtitles_rounded,
        ),
      );
    }

    _ensurePlayer(videoId, segment);
    _syncSegmentAfterBuild(segment, dictation);

    if (_segmentId != segment.id) {
      _segmentId = segment.id;
      _inputController.text = segment.userInput;
      _inputController.selection = TextSelection.collapsed(
        offset: _inputController.text.length,
      );
    }

    final isLast = dictation.currentIndex >= dictation.segments.length - 1;

    return MainScaffold(
      currentIndex: 0,
      appBar: AppBar(title: const Text('Dictation Practice')),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _HeaderCard(
              segment: segment,
              currentIndex: dictation.currentIndex,
              totalSegments: dictation.segments.length,
            ),
            const SizedBox(height: 14),
            _PlayerCard(
              segment: segment,
              controller: _playerController,
              isPlaying: dictation.isPlaying,
              playbackSpeed: dictation.playbackSpeed,
              onPrevious: () => _goToPreviousSegment(context),
              onReplay: () => _replayCurrentSegment(context),
              onPlayPause: () => _togglePlayPause(context),
              onNext: () => _goToNextSegment(context),
              onSpeedChanged: (speed) => _changePlaybackSpeed(context, speed),
            ),
            const SizedBox(height: 14),
            AppCard(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Your dictation',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _inputController,
                    minLines: 4,
                    maxLines: 7,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                        RegExp(r'''[a-zA-Z0-9\s.,!?;:'"-]'''),
                      ),
                    ],
                    textInputAction: TextInputAction.newline,
                    onChanged: dictation.updateUserInput,
                    decoration: const InputDecoration(
                      hintText: 'Type what you hear...',
                      alignLabelWithHint: true,
                    ),
                  ),
                  if (dictation.checkMessage != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      dictation.checkMessage!,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color:
                            dictation.isLastCheckCorrect
                                ? Colors.green
                                : Theme.of(context).colorScheme.error,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 14),
            _AnswerCard(segment: segment, dictation: dictation),
            const SizedBox(height: 14),
            Consumer<DictationProvider>(
              builder: (context, provider, _) {
                return CustomButton(
                  label: 'Save sentence',
                  icon: Icons.save_rounded,
                  style: CustomButtonStyle.secondary,
                  isLoading: provider.isSaving,
                  onPressed:
                      provider.isSaving ? null : () => _saveSentence(context),
                );
              },
            ),
            const SizedBox(height: 14),
            AppCard(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Column(
                children: [
                  SwitchListTile(
                    secondary: const Icon(Icons.fast_forward_rounded),
                    title: const Text('Auto Next'),
                    value: dictation.autoNext,
                    onChanged: (_) => dictation.toggleAutoNext(),
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    secondary: const Icon(Icons.translate_rounded),
                    title: const Text('Hide Translation'),
                    value: dictation.hideTranslation,
                    onChanged: (_) => dictation.toggleTranslation(),
                  ),
                ],
              ),
            ),
            if (!dictation.hideTranslation &&
                segment.translationVi.trim().isNotEmpty) ...[
              const SizedBox(height: 14),
              AppCard(
                padding: const EdgeInsets.all(16),
                child: Text(
                  segment.translationVi,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: colors.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: CustomButton(
                    label: 'Previous',
                    icon: Icons.chevron_left_rounded,
                    style: CustomButtonStyle.outline,
                    onPressed:
                        dictation.currentIndex == 0
                            ? null
                            : () => _goToPreviousSegment(context),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: CustomButton(
                    label: isLast ? 'Finish' : 'Next',
                    icon:
                        isLast
                            ? Icons.flag_rounded
                            : Icons.chevron_right_rounded,
                    onPressed:
                        isLast
                            ? () => _finishPractice(context)
                            : () => _goToNextSegment(context),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({
    required this.segment,
    required this.currentIndex,
    required this.totalSegments,
  });

  final DictationSegment segment;
  final int currentIndex;
  final int totalSegments;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final words = _words(segment.text).length;

    return AppCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Segment ${currentIndex + 1} of $totalSegments',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _InfoChip(
                icon: Icons.schedule_rounded,
                label: _formatTime(segment.startTime),
              ),
              _InfoChip(icon: Icons.notes_rounded, label: '$words words'),
              _InfoChip(
                icon: Icons.timer_rounded,
                label: '${segment.duration.toStringAsFixed(1)}s',
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Listen to the segment and type the sentence below.',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _PlayerCard extends StatelessWidget {
  const _PlayerCard({
    required this.segment,
    required this.controller,
    required this.isPlaying,
    required this.playbackSpeed,
    required this.onPrevious,
    required this.onReplay,
    required this.onPlayPause,
    required this.onNext,
    required this.onSpeedChanged,
  });

  final DictationSegment segment;
  final YoutubePlayerController? controller;
  final bool isPlaying;
  final double playbackSpeed;
  final VoidCallback onPrevious;
  final VoidCallback onReplay;
  final VoidCallback onPlayPause;
  final VoidCallback onNext;
  final ValueChanged<double> onSpeedChanged;

  static const _speeds = [0.5, 0.75, 1.0, 1.25, 1.5];

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return AppCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          if (controller == null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 24),
              decoration: BoxDecoration(
                color: colors.error.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.error_outline_rounded,
                    color: colors.error,
                    size: 34,
                  ),
                  const SizedBox(height: 8),
                  const Text('Cannot load YouTube player'),
                ],
              ),
            )
          else
            ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: YoutubePlayer(
                controller: controller!,
                showVideoProgressIndicator: true,
                progressIndicatorColor: colors.primary,
                progressColors: ProgressBarColors(
                  playedColor: colors.primary,
                  handleColor: colors.secondary,
                ),
              ),
            ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 26),
            decoration: BoxDecoration(
              color: colors.primary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                Text(
                  _formatTime(segment.startTime),
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    color: colors.primary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  isPlaying ? 'Playing segment' : 'Ready to play',
                  style: TextStyle(color: colors.onSurfaceVariant),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _RoundControlButton(
                tooltip: 'Previous Segment',
                icon: Icons.skip_previous_rounded,
                onPressed: onPrevious,
              ),
              _RoundControlButton(
                tooltip: 'Replay',
                icon: Icons.replay_rounded,
                onPressed: onReplay,
              ),
              FilledButton(
                onPressed: onPlayPause,
                style: FilledButton.styleFrom(
                  shape: const CircleBorder(),
                  minimumSize: const Size(62, 62),
                ),
                child: Icon(
                  isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  size: 34,
                ),
              ),
              _RoundControlButton(
                tooltip: 'Next Segment',
                icon: Icons.skip_next_rounded,
                onPressed: onNext,
              ),
            ],
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children:
                _speeds.map((speed) {
                  final selected = playbackSpeed == speed;
                  return ChoiceChip(
                    label: Text('${speed.g}x'),
                    selected: selected,
                    onSelected: (_) => onSpeedChanged(speed),
                  );
                }).toList(),
          ),
        ],
      ),
    );
  }
}

class _AnswerCard extends StatelessWidget {
  const _AnswerCard({required this.segment, required this.dictation});

  final DictationSegment segment;
  final DictationProvider dictation;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final matches =
        dictation.currentCheckResult?.wordMatches ??
        _words(segment.text)
            .map(
              (word) => WordMatch(
                originalWord: word,
                normalizedOriginalWord: '',
                userWord: null,
                isCorrect: false,
              ),
            )
            .toList();

    return AppCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Transcript answer',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: List.generate(matches.length, (index) {
              final match = matches[index];
              final label = _answerLabel(match, index, dictation);
              final isUnlocked =
                  match.isCorrect ||
                  dictation.showAllAnswer ||
                  dictation.revealedWordIndexes.contains(index);
              final backgroundColor =
                  match.isCorrect
                      ? Colors.green.withValues(alpha: 0.14)
                      : isUnlocked
                      ? colors.primary.withValues(alpha: 0.10)
                      : colors.surfaceContainerHighest;
              final textColor =
                  match.isCorrect
                      ? Colors.green.shade700
                      : isUnlocked
                      ? colors.primary
                      : colors.onSurfaceVariant;

              return Chip(
                backgroundColor: backgroundColor,
                label: Text(
                  label,
                  style: TextStyle(
                    color: textColor,
                    fontWeight:
                        match.isCorrect ? FontWeight.w800 : FontWeight.w600,
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: dictation.toggleFirstLetters,
                icon: const Icon(Icons.text_fields_rounded),
                label: const Text('Show First Letters'),
              ),
              OutlinedButton.icon(
                onPressed: dictation.revealNextWord,
                icon: const Icon(Icons.visibility_rounded),
                label: const Text('Reveal Word'),
              ),
              OutlinedButton.icon(
                onPressed: dictation.showAllWords,
                icon: const Icon(Icons.done_all_rounded),
                label: const Text('Show All'),
              ),
              OutlinedButton.icon(
                onPressed: dictation.hideAllWords,
                icon: const Icon(Icons.visibility_off_rounded),
                label: const Text('Hide All'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _answerLabel(WordMatch match, int index, DictationProvider dictation) {
    if (dictation.showAllAnswer ||
        dictation.revealedWordIndexes.contains(index)) {
      return match.originalWord;
    }
    if (match.isCorrect) {
      return match.originalWord;
    }
    if (dictation.showFirstLetters && match.originalWord.isNotEmpty) {
      return '${match.originalWord.substring(0, 1)}...';
    }
    return '...';
  }
}

class _RoundControlButton extends StatelessWidget {
  const _RoundControlButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton.filledTonal(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Chip(avatar: Icon(icon, size: 18), label: Text(label));
  }
}

List<String> _words(String text) {
  return text
      .split(RegExp(r'\s+'))
      .where((word) => word.trim().isNotEmpty)
      .toList();
}

String _formatTime(double seconds) {
  final totalSeconds = seconds.round();
  final minutes = totalSeconds ~/ 60;
  final remainder = totalSeconds % 60;
  return '${minutes.toString().padLeft(2, '0')}:${remainder.toString().padLeft(2, '0')}';
}

extension on double {
  String get g {
    return truncateToDouble() == this ? toStringAsFixed(0) : toString();
  }
}
