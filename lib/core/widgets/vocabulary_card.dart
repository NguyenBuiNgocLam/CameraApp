import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/vocabulary_item.dart';
import '../../providers/vocabulary_provider.dart';
import 'app_card.dart';

class VocabularyCard extends StatelessWidget {
  const VocabularyCard({
    required this.item,
    this.onTap,
    this.showDelete = false,
    super.key,
  });

  final VocabularyItem item;
  final VoidCallback? onTap;
  final bool showDelete;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return AppCard(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: colors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(item.icon, color: colors.primary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.word,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  item.meaning,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 3),
                Text(
                  item.phonetic,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: colors.secondary),
                ),
                const SizedBox(height: 8),
                _VocabularyBadges(item: item),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Pronounce',
            onPressed:
                () => context.read<VocabularyProvider>().speak(item.word),
            icon: const Icon(Icons.volume_up_rounded),
          ),
          IconButton(
            tooltip: 'Favorite',
            onPressed:
                () => context.read<VocabularyProvider>().toggleFavorite(item),
            icon: Icon(
              item.isFavorite
                  ? Icons.favorite_rounded
                  : Icons.favorite_border_rounded,
            ),
            color:
                item.isFavorite ? Colors.pinkAccent : colors.onSurfaceVariant,
          ),
          if (showDelete)
            IconButton(
              tooltip: 'Delete',
              onPressed: () => context.read<VocabularyProvider>().delete(item),
              icon: const Icon(Icons.delete_rounded),
              color: colors.error,
            ),
        ],
      ),
    );
  }
}

class _VocabularyBadges extends StatelessWidget {
  const _VocabularyBadges({required this.item});

  final VocabularyItem item;

  @override
  Widget build(BuildContext context) {
    final badges = <_BadgeData>[
      _levelBadge(item.learningLevel),
      if (_isDueToday(item)) const _BadgeData('Review Today', Icons.today),
      if (item.wrongCount > 0)
        _BadgeData('Wrong: ${item.wrongCount}', Icons.error_outline_rounded),
    ];

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: badges.map((badge) => _Badge(data: badge)).toList(),
    );
  }

  static bool _isDueToday(VocabularyItem item) {
    final nextReviewAt = item.nextReviewAt;
    if (nextReviewAt == null) return false;
    final now = DateTime.now();
    final endOfToday = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
    return !nextReviewAt.isAfter(endOfToday);
  }

  static _BadgeData _levelBadge(String value) {
    final level = value.trim().toLowerCase();
    return switch (level) {
      'mastered' => const _BadgeData(
        'Mastered',
        Icons.verified_rounded,
        Colors.green,
      ),
      'temporary' => const _BadgeData(
        'Temporary',
        Icons.hourglass_bottom_rounded,
        Colors.orange,
      ),
      _ => const _BadgeData(
        'Unknown',
        Icons.help_outline_rounded,
        Colors.blueGrey,
      ),
    };
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.data});

  final _BadgeData data;

  @override
  Widget build(BuildContext context) {
    final color = data.color ?? Theme.of(context).colorScheme.primary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(data.icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(
            data.label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _BadgeData {
  const _BadgeData(this.label, this.icon, [this.color]);

  final String label;
  final IconData icon;
  final Color? color;
}
