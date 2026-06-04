import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/routes.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/custom_button.dart';
import '../../core/widgets/empty_state_widget.dart';
import '../../models/vocabulary_item.dart';
import '../../providers/scan_provider.dart';
import '../../providers/vocabulary_provider.dart';
import '../../services/firebase_app_service.dart';

class AIResultScreen extends StatelessWidget {
  const AIResultScreen({super.key});

  String get _currentUserId {
    if (!FirebaseAppService.isReady) return '';
    return FirebaseAuth.instance.currentUser?.uid ?? '';
  }

  Future<void> _save(BuildContext context, VocabularyItem item) async {
    final userId = _currentUserId;
    if (userId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please login before saving words')),
      );
      return;
    }

    final success = await context.read<VocabularyProvider>().save(
      item.copyWith(userId: userId),
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? 'Saved successfully'
              : context.read<VocabularyProvider>().errorMessage ??
                  'Cannot save word',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scan = context.watch<ScanProvider>();
    final item = scan.result;
    final image = scan.selectedImage;
    final colors = Theme.of(context).colorScheme;
    final userId = _currentUserId;
    final detections = scan.detections;
    final hasDetections = detections.isNotEmpty;
    final selectedIndex = scan.selectedDetectionIndex.clamp(
      0,
      hasDetections ? detections.length - 1 : 0,
    );

    if (item == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('AI Result')),
        body: SafeArea(
          child: Column(
            children: [
              const Expanded(
                child: EmptyStateWidget(
                  title: 'No AI result',
                  message: 'Take or pick a photo, then analyze it first.',
                  icon: Icons.auto_awesome_rounded,
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: CustomButton(
                  label: 'Back to Scan',
                  icon: Icons.camera_alt_rounded,
                  onPressed:
                      () => Navigator.pushReplacementNamed(
                        context,
                        AppRoutes.scan,
                      ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('AI Result')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (hasDetections) ...[
                Row(
                  children: [
                    Text(
                      'Flashcards',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${selectedIndex + 1}/${detections.length}',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: colors.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: List.generate(detections.length, (index) {
                      final object = detections[index];
                      final selected = selectedIndex == index;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          selected: selected,
                          label: Text('${index + 1}. ${object.word}'),
                          onSelected:
                              (_) =>
                                  context.read<ScanProvider>().selectDetection(
                                    index,
                                    userId:
                                        userId.isEmpty ? item.userId : userId,
                                  ),
                        ),
                      );
                    }),
                  ),
                ),
                const SizedBox(height: 14),
              ],
              AppCard(
                padding: const EdgeInsets.all(22),
                child: Column(
                  children: [
                    Stack(
                      alignment: Alignment.topRight,
                      children: [
                        Container(
                          height: 190,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: colors.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(22),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child:
                              image == null
                                  ? Icon(
                                    Icons.photo_camera_rounded,
                                    size: 84,
                                    color: colors.primary,
                                  )
                                  : Image.file(image, fit: BoxFit.cover),
                        ),
                        IconButton.filledTonal(
                          tooltip: 'Favorite',
                          onPressed:
                              () =>
                                  context
                                      .read<ScanProvider>()
                                      .toggleResultFavorite(),
                          icon: Icon(
                            item.isFavorite
                                ? Icons.favorite_rounded
                                : Icons.favorite_border_rounded,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Text(
                      item.word,
                      style: Theme.of(context).textTheme.displaySmall?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      item.phonetic,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: colors.secondary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Chip(label: Text(item.partOfSpeech)),
                    const SizedBox(height: 18),
                    _InfoRow(
                      title: 'Meaning Vietnamese',
                      value: item.meaningVi,
                    ),
                    _InfoRow(title: 'Example', value: item.exampleEn),
                    _InfoRow(title: 'Translation', value: item.exampleVi),
                  ],
                ),
              ),
              if (hasDetections && detections.length > 1) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: CustomButton(
                        label: 'Previous',
                        icon: Icons.chevron_left_rounded,
                        style: CustomButtonStyle.outline,
                        onPressed:
                            selectedIndex == 0
                                ? null
                                : () => context
                                    .read<ScanProvider>()
                                    .selectDetection(
                                      selectedIndex - 1,
                                      userId:
                                          userId.isEmpty ? item.userId : userId,
                                    ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: CustomButton(
                        label: 'Next',
                        icon: Icons.chevron_right_rounded,
                        style: CustomButtonStyle.outline,
                        onPressed:
                            selectedIndex >= detections.length - 1
                                ? null
                                : () => context
                                    .read<ScanProvider>()
                                    .selectDetection(
                                      selectedIndex + 1,
                                      userId:
                                          userId.isEmpty ? item.userId : userId,
                                    ),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 18),
              CustomButton(
                label: 'Pronounce',
                icon: Icons.volume_up_rounded,
                onPressed:
                    () => context.read<VocabularyProvider>().speak(item.word),
              ),
              const SizedBox(height: 12),
              Consumer<VocabularyProvider>(
                builder: (context, vocabulary, _) {
                  return CustomButton(
                    label: 'Save Word',
                    icon: Icons.bookmark_add_rounded,
                    style: CustomButtonStyle.secondary,
                    isLoading: vocabulary.isLoading,
                    onPressed: () => _save(context, item),
                  );
                },
              ),
              const SizedBox(height: 12),
              CustomButton(
                label: 'Try Again',
                icon: Icons.refresh_rounded,
                style: CustomButtonStyle.outline,
                onPressed: () {
                  context.read<ScanProvider>().clear();
                  Navigator.pushReplacementNamed(context, AppRoutes.scan);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.title, required this.value});

  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}
