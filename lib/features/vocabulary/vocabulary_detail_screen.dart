import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/widgets/app_card.dart';
import '../../core/widgets/custom_button.dart';
import '../../models/vocabulary_item.dart';
import '../../providers/vocabulary_provider.dart';

class VocabularyDetailScreen extends StatelessWidget {
  const VocabularyDetailScreen({required this.item, super.key});

  final VocabularyItem item;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<VocabularyProvider>();
    final currentItem =
        provider.items.cast<VocabularyItem?>().firstWhere(
          (value) => value?.id == item.id,
          orElse: () => item,
        )!;
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Word Detail')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppCard(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    CircleAvatar(
                      radius: 42,
                      backgroundColor: colors.primary.withValues(alpha: 0.12),
                      child: Icon(
                        currentItem.icon,
                        color: colors.primary,
                        size: 38,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      currentItem.word,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.displaySmall?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      currentItem.meaningVi,
                      textAlign: TextAlign.center,
                      style: Theme.of(
                        context,
                      ).textTheme.titleLarge?.copyWith(color: colors.primary),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        Chip(label: Text(currentItem.phonetic)),
                        Chip(label: Text(currentItem.partOfSpeech)),
                      ],
                    ),
                    const SizedBox(height: 22),
                    _DetailBlock(
                      title: 'Example sentence',
                      value: currentItem.exampleEn,
                    ),
                    _DetailBlock(
                      title: 'Translation',
                      value: currentItem.exampleVi,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              CustomButton(
                label: 'Pronounce',
                icon: Icons.volume_up_rounded,
                onPressed: () => provider.speak(currentItem.word),
              ),
              const SizedBox(height: 12),
              CustomButton(
                label: currentItem.isFavorite ? 'Favorited' : 'Add Favorite',
                icon:
                    currentItem.isFavorite
                        ? Icons.favorite_rounded
                        : Icons.favorite_border_rounded,
                style: CustomButtonStyle.secondary,
                onPressed:
                    () => context.read<VocabularyProvider>().toggleFavorite(
                      currentItem,
                    ),
              ),
              const SizedBox(height: 12),
              CustomButton(
                label: 'Delete Word',
                icon: Icons.delete_rounded,
                style: CustomButtonStyle.danger,
                onPressed: () async {
                  await context.read<VocabularyProvider>().delete(currentItem);
                  if (!context.mounted) return;
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailBlock extends StatelessWidget {
  const _DetailBlock({required this.title, required this.value});

  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 6),
          Text(value, style: Theme.of(context).textTheme.titleMedium),
        ],
      ),
    );
  }
}
