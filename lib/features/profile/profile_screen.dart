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
import '../../providers/vocabulary_provider.dart';
import '../dashboard/providers/dashboard_provider.dart';
import '../settings/providers/reminder_provider.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _loaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loaded) return;
    final userId = context.read<AuthProvider>().user?.uid;
    if (userId != null) {
      _loaded = true;
      final vocabulary = context.read<VocabularyProvider>();
      Future.microtask(() async {
        await vocabulary.load();
        if (!mounted) return;
        await context.read<DashboardProvider>().loadDashboard();
        if (!mounted) return;
        await context.read<ReminderProvider>().loadReminderSettings();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeController = ThemeController.of(context);
    final colors = Theme.of(context).colorScheme;
    final auth = context.watch<AuthProvider>();
    final dashboard = context.watch<DashboardProvider>();
    final stats = dashboard.stats;
    final user = auth.user;

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
                  value: '${stats.totalWords}',
                  icon: Icons.menu_book_rounded,
                ),
                StatCard(
                  title: 'Mastered words',
                  value: '${stats.masteredWords}',
                  icon: Icons.verified_rounded,
                  color: AppColors.warning,
                ),
                StatCard(
                  title: 'Current streak',
                  value: '${stats.currentStreak}',
                  icon: Icons.local_fire_department_rounded,
                  color: AppColors.secondary,
                ),
                StatCard(
                  title: 'Longest streak',
                  value: '${stats.longestStreak}',
                  icon: Icons.emoji_events_rounded,
                  color: AppColors.success,
                ),
              ],
            ),
            const SizedBox(height: 18),
            AppCard(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Learning Dashboard',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _ProfileMetricRow(
                    icon: Icons.calendar_month_rounded,
                    label: 'Total learning days',
                    value: '${stats.totalLearningDays}',
                  ),
                  _ProfileMetricRow(
                    icon: Icons.subtitles_rounded,
                    label: 'Dictation sessions',
                    value: '${stats.dictationSessions}',
                  ),
                  _ProfileMetricRow(
                    icon: Icons.today_rounded,
                    label: 'Words learned today',
                    value: '${stats.wordsLearnedToday}',
                  ),
                  _ProfileMetricRow(
                    icon: Icons.replay_rounded,
                    label: 'Reviewed today',
                    value: '${stats.reviewedWordsToday}',
                  ),
                  if (dashboard.errorMessage != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      dashboard.errorMessage!,
                      style: TextStyle(color: colors.error),
                    ),
                  ],
                ],
              ),
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
                  const _DailyReminderSection(),
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

class _DailyReminderSection extends StatefulWidget {
  const _DailyReminderSection();

  @override
  State<_DailyReminderSection> createState() => _DailyReminderSectionState();
}

class _DailyReminderSectionState extends State<_DailyReminderSection> {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Show SnackBar feedback whenever successMessage or errorMessage changes.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final reminder = context.read<ReminderProvider>();
      if (reminder.successMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(reminder.successMessage!),
            backgroundColor: Colors.green.shade700,
            behavior: SnackBarBehavior.floating,
          ),
        );
        reminder.successMessage = null;
      } else if (reminder.errorMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(reminder.errorMessage!),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
          ),
        );
        reminder.errorMessage = null;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final reminder = context.watch<ReminderProvider>();
    final timeLabel = reminder.reminderTime.format(context);

    // Trigger SnackBar on every rebuild when messages are present.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (reminder.successMessage != null) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(reminder.successMessage!),
            backgroundColor: Colors.green.shade700,
            behavior: SnackBarBehavior.floating,
          ),
        );
        reminder.successMessage = null;
      } else if (reminder.errorMessage != null) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(reminder.errorMessage!),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
          ),
        );
        reminder.errorMessage = null;
      }
    });

    return Column(
      children: [
        SwitchListTile(
          secondary: const Icon(Icons.notifications_active_rounded),
          title: const Text('Daily Reminder'),
          subtitle: Text('Reminder time: $timeLabel'),
          value: reminder.dailyReminderEnabled,
          onChanged: reminder.isLoading ? null : reminder.toggleReminder,
        ),
        ListTile(
          leading: const Icon(Icons.schedule_rounded),
          title: const Text('Choose reminder time'),
          subtitle: Text(timeLabel),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap:
              reminder.isLoading
                  ? null
                  : () async {
                    final picked = await showTimePicker(
                      context: context,
                      initialTime: reminder.reminderTime,
                    );
                    if (picked == null || !context.mounted) return;
                    await context.read<ReminderProvider>().updateReminderTime(
                      picked,
                    );
                  },
        ),
        // Test notification UI removed per user request.
      ],
    );
  }
}

class _ProfileMetricRow extends StatelessWidget {
  const _ProfileMetricRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: colors.primary.withValues(alpha: 0.10),
            child: Icon(icon, color: colors.primary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}
