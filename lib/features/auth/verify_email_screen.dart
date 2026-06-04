import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/routes.dart';
import '../../core/widgets/custom_button.dart';
import '../../providers/auth_provider.dart';

class VerifyEmailScreen extends StatelessWidget {
  const VerifyEmailScreen({super.key});

  Future<void> _checkVerification(BuildContext context) async {
    final auth = context.read<AuthProvider>();
    final verified = await auth.checkEmailVerification();
    if (!context.mounted) return;

    if (verified) {
      Navigator.pushNamedAndRemoveUntil(context, AppRoutes.home, (_) => false);
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Email is not verified yet. Please check your inbox.'),
      ),
    );
  }

  Future<void> _resendEmail(BuildContext context) async {
    final auth = context.read<AuthProvider>();
    final sent = await auth.resendVerificationEmail();
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          sent
              ? 'Verification email sent.'
              : auth.errorMessage ?? 'Cannot send verification email.',
        ),
      ),
    );
  }

  Future<void> _logout(BuildContext context) async {
    await context.read<AuthProvider>().logout();
    if (!context.mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, AppRoutes.login, (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final auth = context.watch<AuthProvider>();
    final email = auth.user?.email ?? '';

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                CircleAvatar(
                  radius: 42,
                  backgroundColor: colors.primary.withValues(alpha: 0.12),
                  child: Icon(
                    Icons.mark_email_read_rounded,
                    color: colors.primary,
                    size: 42,
                  ),
                ),
                const SizedBox(height: 28),
                Text(
                  'Verify your email',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'We sent a verification link to your Gmail.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
                if (email.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Text(
                    email,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: colors.primary,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Text(
                  'Please check Inbox or Spam, then come back and tap the button below.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: colors.onSurfaceVariant),
                ),
                const SizedBox(height: 30),
                CustomButton(
                  label: 'I have verified',
                  icon: Icons.verified_rounded,
                  isLoading: auth.isLoading,
                  onPressed:
                      auth.isLoading ? null : () => _checkVerification(context),
                ),
                const SizedBox(height: 12),
                CustomButton(
                  label: 'Resend email',
                  icon: Icons.send_rounded,
                  style: CustomButtonStyle.secondary,
                  isLoading: auth.isLoading,
                  onPressed:
                      auth.isLoading ? null : () => _resendEmail(context),
                ),
                const SizedBox(height: 12),
                CustomButton(
                  label: 'Logout / Change account',
                  icon: Icons.logout_rounded,
                  style: CustomButtonStyle.outline,
                  onPressed: auth.isLoading ? null : () => _logout(context),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
