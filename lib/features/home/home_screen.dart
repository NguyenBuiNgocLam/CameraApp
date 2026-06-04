import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/routes.dart';
import '../../core/constants/app_colors.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/custom_button.dart';
import '../../core/widgets/main_scaffold.dart';
import '../../core/widgets/stat_card.dart';
import '../../core/widgets/vocabulary_card.dart';
import '../../providers/auth_provider.dart';
import '../../providers/quiz_provider.dart';
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
    _loaded = true;
    final userId = context.read<AuthProvider>().user?.uid;
    final vocabulary = context.read<VocabularyProvider>();
    if (userId != null) {
      Future.microtask(() async {
        await vocabulary.load();
        if (!mounted) return;
        await context.read<QuizProvider>().loadResults(userId);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final auth = context.watch<AuthProvider>();
    final vocabulary = context.watch<VocabularyProvider>();
    final quiz = context.watch<QuizProvider>();
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
                  value: '${vocabulary.totalWords}',
                  icon: Icons.menu_book_rounded,
                ),
                StatCard(
                  title: 'Quiz completed',
                  value: '${quiz.quizCompleted(userId)}',
                  icon: Icons.quiz_rounded,
                  color: AppColors.secondary,
                ),
                StatCard(
                  title: 'Favorite words',
                  value: '${vocabulary.favoriteWords}',
                  icon: Icons.favorite_rounded,
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
                      color: colors.error.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Icon(
                      Icons.play_circle_fill_rounded,
                      color: colors.error,
                      size: 32,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'YouTube Dictation',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Practice listening from YouTube videos',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 18),
                  CustomButton(
                    label: 'Start Practice',
                    icon: Icons.subtitles_rounded,
                    style: CustomButtonStyle.secondary,
                    onPressed:
                        () => Navigator.pushNamed(
                          context,
                          AppRoutes.dictationHome,
                        ),
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
