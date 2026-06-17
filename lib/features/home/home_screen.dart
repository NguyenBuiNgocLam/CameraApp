import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/routes.dart';
import '../../core/constants/app_colors.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/custom_button.dart';
import '../../core/widgets/main_scaffold.dart';
import '../../core/widgets/stat_card.dart';
import '../../core/widgets/vocabulary_card.dart';
import '../dashboard/providers/dashboard_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/vocabulary_provider.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _loaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loaded) return;
    final userId = context.read<AuthProvider>().user?.uid;
    final vocabulary = context.read<VocabularyProvider>();
    if (userId != null) {
      _loaded = true;
      Future.microtask(() async {
        await vocabulary.load();
        if (!mounted) return;
        await context.read<DashboardProvider>().loadDashboard();
      });
    }
  }

  Future<void> _openTodayReview(String userId) async {
    if (context.read<DashboardProvider>().stats.todayReviewCount == 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No words to review today')));
      return;
    }
    await Navigator.pushNamed(context, AppRoutes.todayReview, arguments: true);
    if (!mounted || userId.trim().isEmpty) return;
    await context.read<DashboardProvider>().refreshDashboard();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final auth = context.watch<AuthProvider>();
    final vocabulary = context.watch<VocabularyProvider>();
    final dashboard = context.watch<DashboardProvider>();
    final stats = dashboard.stats;
    final recentWords = vocabulary.items.take(3).toList();
    final name = auth.user?.name.split(' ').first ?? 'Nhan';
    final userId = auth.user?.uid ?? '';

    return MainScaffold(
      currentIndex: 0,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Hi, $name',
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'What do you want to learn today?',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                CircleAvatar(
                  radius: 25,
                  backgroundColor: colors.primary.withValues(alpha: 0.12),
                  child: Icon(Icons.person_rounded, color: colors.primary),
                ),
              ],
            ),
            const SizedBox(height: 24),
            GridView.count(
              crossAxisCount: 3,
              childAspectRatio: 0.82,
              crossAxisSpacing: 10,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                StatCard(
                  title: 'Words learned',
                  value: '${stats.totalWords}',
                  icon: Icons.menu_book_rounded,
                ),
                StatCard(
                  title: 'Mastered words',
                  value: '${stats.masteredWords}',
                  icon: Icons.verified_rounded,
                  color: AppColors.secondary,
                ),
                StatCard(
                  title: 'Current streak',
                  value: '${stats.currentStreak}',
                  icon: Icons.local_fire_department_rounded,
                  color: AppColors.warning,
                ),
              ],
            ),
            const SizedBox(height: 22),
            AppCard(
              padding: const EdgeInsets.all(22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      color: colors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Icon(
                      Icons.event_available_rounded,
                      color: colors.primary,
                      size: 32,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Today Review',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    dashboard.errorMessage != null
                        ? 'Cannot load review queue'
                        : dashboard.isLoading
                        ? 'Checking review queue...'
                        : stats.todayReviewCount == 0
                        ? 'No words to review today'
                        : 'You have ${stats.todayReviewCount} words to review today',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color:
                          dashboard.errorMessage != null
                              ? colors.error
                              : colors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 18),
                  CustomButton(
                    label: 'Start Review',
                    icon: Icons.school_rounded,
                    onPressed:
                        userId.isEmpty ? null : () => _openTodayReview(userId),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            AppCard(
              padding: const EdgeInsets.all(22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Vocabulary Progress',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 14),
                  _ProgressRow(
                    label: 'Mastered',
                    value: stats.masteredWords,
                    total: stats.totalWords,
                    color: AppColors.success,
                  ),
                  const SizedBox(height: 12),
                  _ProgressRow(
                    label: 'Temporary',
                    value: stats.temporaryWords,
                    total: stats.totalWords,
                    color: AppColors.warning,
                  ),
                  const SizedBox(height: 12),
                  _ProgressRow(
                    label: 'Unknown',
                    value: stats.unknownWords,
                    total: stats.totalWords,
                    color: colors.primary,
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: _MiniMetric(
                          title: 'Words today',
                          value: '${stats.wordsLearnedToday}',
                          icon: Icons.add_circle_rounded,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _MiniMetric(
                          title: 'Reviewed',
                          value: '${stats.reviewedWordsToday}',
                          icon: Icons.replay_circle_filled_rounded,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            AppCard(
              padding: const EdgeInsets.all(22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [colors.primary, colors.secondary],
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(
                      Icons.camera_alt_rounded,
                      color: Colors.white,
                      size: 30,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Scan Object',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Take a photo and learn its English name',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 18),
                  CustomButton(
                    label: 'Start Scanning',
                    icon: Icons.camera_alt_rounded,
                    onPressed:
                        () => Navigator.pushNamed(context, AppRoutes.scan),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 26),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Recent Words',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                ),
                TextButton(
                  onPressed:
                      () => Navigator.pushReplacementNamed(
                        context,
                        AppRoutes.vocabulary,
                      ),
                  child: const Text('View all'),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ...recentWords.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: VocabularyCard(
                  item: item,
                  onTap:
                      () => Navigator.pushNamed(
                        context,
                        AppRoutes.vocabularyDetail,
                        arguments: item,
                      ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProgressRow extends StatelessWidget {
  const _ProgressRow({
    required this.label,
    required this.value,
    required this.total,
    required this.color,
  });

  final String label;
  final int value;
  final int total;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final percent = total == 0 ? 0.0 : value / total;
    final colors = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
            Text(
              '$value/$total',
              style: TextStyle(color: colors.onSurfaceVariant),
            ),
          ],
        ),
        const SizedBox(height: 7),
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: SizedBox(
            height: 9,
            child: LinearProgressIndicator(
              value: percent.clamp(0, 1),
              color: color,
              backgroundColor: color.withValues(alpha: 0.14),
            ),
          ),
        ),
      ],
    );
  }
}

class _MiniMetric extends StatelessWidget {
  const _MiniMetric({
    required this.title,
    required this.value,
    required this.icon,
  });

  final String title;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      constraints: const BoxConstraints(minHeight: 86),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: colors.primary),
          const SizedBox(height: 8),
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
          ),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: colors.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
