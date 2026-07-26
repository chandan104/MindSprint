import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mindsprint_student/core/router/app_router.dart';
import 'package:mindsprint_student/core/theme/app_theme.dart';
import 'package:mindsprint_student/features/auth/presentation/auth_controller.dart';

/// The app now boots through a splash screen that restores any persisted
/// session. With no session present it lands on login — override the session
/// probe so tests don't need a live Supabase instance.
void main() {
  testWidgets('app boots to the teacher login screen', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [hasPersistedSessionProvider.overrideWithValue(() => false)],
        child: MaterialApp.router(
          theme: AppTheme.dark(),
          routerConfig: buildRouter(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Teacher sign in'), findsOneWidget);
    expect(find.text('Sign in'), findsOneWidget);
  });

  testWidgets('login form validates before submitting', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [hasPersistedSessionProvider.overrideWithValue(() => false)],
        child: MaterialApp.router(
          theme: AppTheme.dark(),
          routerConfig: buildRouter(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();

    expect(find.text('Enter a valid email address'), findsOneWidget);
    expect(find.text('Enter the password'), findsOneWidget);
  });
}
