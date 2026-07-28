import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import 'auth_controller.dart';

/// First screen on every launch. It restores a persisted session before any
/// login form is shown, so teachers who are already signed in go straight to
/// the roster and never see a flash of the login screen. A valid session
/// survives app restarts, reboots, updates, and offline reopening.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _restore());
  }

  Future<void> _restore() async {
    final result = await ref.read(authControllerProvider.notifier).restore();
    if (!mounted) return;
    switch (result) {
      case RestoreResult.authenticated:
        context.go(AppRoutes.classes);
      case RestoreResult.unauthenticated:
      case RestoreResult.versionBlocked:
        context.go(AppRoutes.login);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.psychology_outlined, size: 72, color: scheme.primary),
            const SizedBox(height: 16),
            Text('Skill Lab',
                style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 24),
            const SizedBox(
              height: 24,
              width: 24,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            ),
            const SizedBox(height: 12),
            Text('Restoring session…',
                style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}
