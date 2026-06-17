import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app/routes.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/custom_button.dart';
import '../../../core/widgets/custom_text_field.dart';
import '../../../core/widgets/main_scaffold.dart';
import '../models/dictation_segment.dart';
import '../models/dictation_session.dart';
import '../providers/dictation_provider.dart';

class DictationHomeScreen extends StatefulWidget {
  const DictationHomeScreen({super.key});

  @override
  State<DictationHomeScreen> createState() => _DictationHomeScreenState();
}

class _DictationHomeScreenState extends State<DictationHomeScreen> {
  final _urlController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final provider = context.read<DictationProvider>();
    _urlController.text = provider.youtubeUrl ?? '';
    Future.microtask(provider.loadRecentSessions);
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _fetchTranscript(BuildContext context) async {
    await context.read<DictationProvider>().fetchTranscript();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final dictation = context.watch<DictationProvider>();
    final hasResult =
        dictation.videoTitle != null && dictation.segments.isNotEmpty;

    return MainScaffold(
      currentIndex: 3,
      appBar: AppBar(title: const Text('YouTube Dictation')),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppCard(
              padding: const EdgeInsets.all(22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      color: colors.error.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Icon(
                      Icons.play_circle_fill_rounded,
                      color: colors.error,
                      size: 34,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'YouTube Dictation',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Practice listening from YouTube videos',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  CustomTextField(
                    label: 'YouTube URL',
                    hint: 'https://www.youtube.com/watch?v=...',
                    prefixIcon: Icons.link_rounded,
                    controller: _urlController,
                    keyboardType: TextInputType.url,
                    onChanged:
                        context.read<DictationProvider>().updateYoutubeUrl,
                  ),
                  const SizedBox(height: 16),
                  CustomButton(
                    label: 'Get Transcript',
                    icon: Icons.subtitles_rounded,
                    isLoading: dictation.isLoading,
                    onPressed:
                        dictation.isLoading
                            ? null
                            : () => _fetchTranscript(context),
                  ),
                ],
              ),
            ),
            if (dictation.errorMessage != null) ...[
              const SizedBox(height: 16),
              AppCard(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.error_outline_rounded, color: colors.error),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        dictation.errorMessage!,
                        style: Theme.of(
                          context,
                        ).textTheme.bodyMedium?.copyWith(color: colors.error),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Dismiss',
                      onPressed: context.read<DictationProvider>().clearError,
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
            ],
            if (dictation.isLoading) ...[
              const SizedBox(height: 20),
              const Center(child: CircularProgressIndicator()),
            ],
            if (hasResult) ...[
              const SizedBox(height: 18),
              AppCard(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      dictation.videoTitle!,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${dictation.segments.length} transcript segments ready',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 16),
                    CustomButton(
                      label: 'Start Practice',
                      icon: Icons.play_arrow_rounded,
                      style: CustomButtonStyle.secondary,
                      onPressed: () {
                        _startPractice(context, dictation);
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Preview',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 10),
              ...dictation.segments
                  .take(3)
                  .map(
                    (segment) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _SegmentPreview(segment: segment),
                    ),
                  ),
            ],
            const SizedBox(height: 18),
            _RecentSessionsSection(dictation: dictation),
          ],
        ),
      ),
    );
  }

  Future<void> _startPractice(
    BuildContext context,
    DictationProvider dictation,
  ) async {
    final success = await context
        .read<DictationProvider>()
        .createAndStartSession(
          youtubeUrl: dictation.youtubeUrl ?? _urlController.text,
          videoTitle: dictation.videoTitle!,
          segments: dictation.segments,
        );
    if (!context.mounted) return;
    if (success) {
      Navigator.pushNamed(context, AppRoutes.dictationPractice);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.read<DictationProvider>().saveErrorMessage ??
                'Cannot start dictation session',
          ),
        ),
      );
    }
  }
}

class _RecentSessionsSection extends StatelessWidget {
  const _RecentSessionsSection({required this.dictation});

  final DictationProvider dictation;

  @override
  Widget build(BuildContext context) {
    if (dictation.isLoadingSessions) {
      return const Center(child: CircularProgressIndicator());
    }

    if (dictation.recentSessions.isEmpty) {
      return AppCard(
        padding: const EdgeInsets.all(18),
        child: Text(
          'No recent dictation sessions yet.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Recent Sessions',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 10),
        ...dictation.recentSessions.map(
          (session) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _RecentSessionCard(session: session),
          ),
        ),
      ],
    );
  }
}

class _RecentSessionCard extends StatelessWidget {
  const _RecentSessionCard({required this.session});

  final DictationSession session;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final progress =
        session.totalSegments == 0 ? 0 : session.currentSegmentIndex + 1;

    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            session.videoTitle,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          Text(
            '$progress/${session.totalSegments} segments • ${_formatDate(session.updatedAt)}',
            style: TextStyle(color: colors.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: CustomButton(
                  label: 'Continue',
                  icon: Icons.play_arrow_rounded,
                  style: CustomButtonStyle.secondary,
                  onPressed: () => _continueSession(context),
                ),
              ),
              const SizedBox(width: 10),
              IconButton.filledTonal(
                tooltip: 'Delete',
                onPressed: () => _deleteSession(context),
                icon: const Icon(Icons.delete_rounded),
                color: colors.error,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _continueSession(BuildContext context) async {
    final success = await context.read<DictationProvider>().continueSession(
      session,
    );
    if (!context.mounted) return;
    if (success) {
      Navigator.pushNamed(context, AppRoutes.dictationPractice);
    }
  }

  Future<void> _deleteSession(BuildContext context) async {
    await context.read<DictationProvider>().deleteDictationSession(session);
    if (!context.mounted) return;
    final error = context.read<DictationProvider>().saveErrorMessage;
    if (error != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error)));
    }
  }

  String _formatDate(DateTime value) {
    return '${value.month.toString().padLeft(2, '0')}/'
        '${value.day.toString().padLeft(2, '0')} '
        '${value.hour.toString().padLeft(2, '0')}:'
        '${value.minute.toString().padLeft(2, '0')}';
  }
}

class _SegmentPreview extends StatelessWidget {
  const _SegmentPreview({required this.segment});

  final DictationSegment segment;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Chip(label: Text('#${segment.index + 1}')),
              const SizedBox(width: 8),
              Text(
                _formatTime(segment.startTime),
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: colors.primary,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              Text(
                '${segment.duration.toStringAsFixed(1)}s',
                style: TextStyle(color: colors.onSurfaceVariant),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            segment.text,
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  String _formatTime(double seconds) {
    final totalSeconds = seconds.round();
    final minutes = totalSeconds ~/ 60;
    final remainder = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainder.toString().padLeft(2, '0')}';
  }
}
