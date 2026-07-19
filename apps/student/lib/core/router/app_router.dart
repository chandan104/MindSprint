import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/login_screen.dart';
import '../../features/roster/presentation/class_list_screen.dart';
import '../../features/roster/presentation/student_list_screen.dart';
import '../../features/session/domain/session_args.dart';
import '../../features/session/presentation/assessment_setup_screen.dart';
import '../../features/session/presentation/session_screen.dart';

/// Route table. The session route is kiosk-locked by the SessionScreen
/// itself (PopScope + PIN gate) so the guard also covers system back
/// gestures, not just router navigation.
class AppRoutes {
  AppRoutes._();
  static const login = '/login';
  static const classes = '/classes';
  static const students = '/classes/:classId/students';
  static const setup = '/setup';
  static const session = '/session';

  static String studentsFor(String classId) => '/classes/$classId/students';
}

GoRouter buildRouter() {
  return GoRouter(
    initialLocation: AppRoutes.login,
    routes: [
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.classes,
        builder: (context, state) => const ClassListScreen(),
      ),
      GoRoute(
        path: AppRoutes.students,
        builder: (context, state) => StudentListScreen(
          classId: state.pathParameters['classId']!,
        ),
      ),
      GoRoute(
        path: AppRoutes.setup,
        builder: (context, state) => AssessmentSetupScreen(
          student: state.extra as ConfirmedStudent,
        ),
      ),
      GoRoute(
        path: AppRoutes.session,
        builder: (context, state) => SessionScreen(
          args: state.extra as SessionRunArgs,
        ),
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(child: Text('Page not found: ${state.uri}')),
    ),
  );
}
