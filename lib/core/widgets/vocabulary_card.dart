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
