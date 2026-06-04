import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/app.dart';
import '../../app/routes.dart';
import '../../core/constants/app_colors.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/custom_button.dart';
import '../../core/widgets/main_scaffold.dart';
import '../../core/widgets/stat_card.dart';
import '../../providers/auth_provider.dart';
import '../../providers/quiz_provider.dart';
import '../../providers/vocabulary_provider.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _notifications = true;
  bool _loaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loaded) return;
    _loaded = true;
    final userId = context.read<AuthProvider>().user?.uid;
    if (userId != null) {
      final vocabulary = context.read<VocabularyProvider>();
      final quiz = context.read<QuizProvider>();
      Future.microtask(() async {
        await vocabulary.load();
        if (!mounted) return;
        await quiz.loadResults(userId);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeController = ThemeController.of(context);
    final colors = Theme.of(context).colorScheme;
    final auth = context.watch<AuthProvider>();
    final vocabulary = context.watch<VocabularyProvider>();
    final quiz = context.watch<QuizProvider>();
    final user = auth.user;
    final userId = user?.uid ?? '';

    return MainScaffold(
      currentIndex: 4,
      appBar: AppBar(title: const Text('Profile')),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          children: [
            AppCard(
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 44,
                    backgroundColor: colors.primary.withValues(alpha: 0.14),
                    child: Icon(
                      Icons.person_rounded,
                      color: colors.primary,
                      size: 48,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    user?.name ?? 'User',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    user?.email ?? '',
                    style: TextStyle(color: colors.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            GridView.count(
              crossAxisCount: 2,
              childAspectRatio: 1.12,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                StatCard(
                  title: 'Total words',
                  value: '${vocabulary.totalWords}',
                  icon: Icons.menu_book_rounded,
                ),
                StatCard(
                  title: 'Favorite words',
                  value: '${vocabulary.favoriteWords}',
                  icon: Icons.favorite_rounded,
                  color: AppColors.warning,
                ),
                StatCard(
                  title: 'Quiz completed',
                  value: '${quiz.quizCompleted(userId)}',
                  icon: Icons.quiz_rounded,
                  color: AppColors.secondary,
                ),
                StatCard(
                  title: 'Best score',
                  value: '${quiz.bestScore(userId)}/5',
                  icon: Icons.star_rounded,
                  color: AppColors.success,
                ),
              ],
            ),
            const SizedBox(height: 18),
            AppCard(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Column(
                children: [
                  SwitchListTile(
                    secondary: const Icon(Icons.dark_mode_rounded),
                    title: const Text('Dark mode'),
                    value: themeController.isDarkMode,
                    onChanged: themeController.setDarkMode,
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    secondary: const Icon(Icons.notifications_rounded),
                    title: const Text('Notifications'),
                    value: _notifications,
                    onChanged:
                        (value) => setState(() => _notifications = value),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            CustomButton(
              label: 'Logout',
              icon: Icons.logout_rounded,
              style: CustomButtonStyle.danger,
              isLoading: auth.isLoading,
              onPressed: () async {
                await context.read<AuthProvider>().logout();
                if (!context.mounted) return;
                Navigator.pushNamedAndRemoveUntil(
                  context,
                  AppRoutes.login,
                  (_) => false,
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
