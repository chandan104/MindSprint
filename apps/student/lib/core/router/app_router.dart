import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/login_screen.dart';
import '../../features/roster/presentation/class_list_screen.dart';
import '../../features/roster/presentation/student_list_screen.dart';
import '../../features/session/presentation/session_stub_screen.dart';

/// Route table. Session routes are kiosk-locked: once a student holds the
/// device, leaving the session flow requires the teacher's PIN (enforced by
/// the session screens themselves via PopScope + PIN gate, not by the router,
/// so the guard also covers system back gestures).
class AppRoutes {
  AppRoutes._();
  static const login = '/login';
  static const classes = '/classes';
  static const students = '/classes/:classId/students';
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
        path: AppRoutes.session,
        builder: (context, state) => SessionStubScreen(
          args: state.extra as SessionStubArgs,
        ),
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(child: Text('Page not found: ${state.uri}')),
    ),
  );
}
