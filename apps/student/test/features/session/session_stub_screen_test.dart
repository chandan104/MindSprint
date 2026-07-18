import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mindsprint_student/core/di/providers.dart';
import 'package:mindsprint_student/data/local/app_database.dart';
import 'package:mindsprint_student/features/auth/domain/pin_service.dart';
import 'package:mindsprint_student/features/auth/presentation/auth_controller.dart';
import 'package:mindsprint_student/features/session/presentation/session_stub_screen.dart';

/// PIN service with a fixed PIN and no platform storage.
class _FakePinService extends PinService {
  @override
  Future<bool> hasPin() async => true;

  @override
  Future<bool> verify(String pin) async => pin == '1234';
}

const _args = SessionStubArgs(
  studentId: 'st1',
  studentName: 'Aarav Sharma',
  classId: 'c1',
);

/// The session screen runs a perpetual 100 ms UI ticker, so pumpAndSettle
/// never settles; step frames explicitly instead.
Future<void> pumpFrames(WidgetTester tester, [int frames = 8]) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() => db.close());

  Widget app() => ProviderScope(
        overrides: [
          pinServiceProvider.overrideWithValue(_FakePinService()),
          appDatabaseProvider.overrideWithValue(db),
        ],
        child: const MaterialApp(home: SessionStubScreen(args: _args)),
      );

  testWidgets('shows the confirmed student name and starts the session clock',
      (tester) async {
    await tester.pumpWidget(app());
    await pumpFrames(tester);

    expect(find.text('Aarav Sharma'), findsOneWidget);
    expect(find.textContaining('Session clock:'), findsOneWidget);

    // session_started was recorded into the local event store.
    final events = await db.eventsForSession(
        (tester.state(find.byType(SessionStubScreen)) as dynamic)
            .debugSessionIdForTest as String);
    expect(events.single.eventType, 'session_started');
  });

  testWidgets('system back does not leave the session', (tester) async {
    await tester.pumpWidget(app());

    final dynamic widgetsAppState = tester.state(find.byType(WidgetsApp));
    await widgetsAppState.didPopRoute();
    await pumpFrames(tester);

    expect(find.text('Aarav Sharma'), findsOneWidget);
    expect(find.text('Teacher PIN'), findsOneWidget);
  });

  testWidgets('wrong PIN keeps the session locked', (tester) async {
    await tester.pumpWidget(app());

    await tester.tap(find.text('Teacher exit'));
    await pumpFrames(tester);
    await tester.enterText(find.byType(TextField), '9999');
    await tester.tap(find.text('Unlock'));
    await pumpFrames(tester);

    expect(find.text('Wrong PIN'), findsOneWidget);
    expect(find.text('Aarav Sharma'), findsOneWidget);
  });

  testWidgets(
      'correct PIN records session_aborted and leaves the session screen',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          pinServiceProvider.overrideWithValue(_FakePinService()),
          appDatabaseProvider.overrideWithValue(db),
        ],
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: FilledButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const SessionStubScreen(args: _args),
                    ),
                  ),
                  child: const Text('Launch'),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Launch'));
    await pumpFrames(tester);
    expect(find.text('Aarav Sharma'), findsOneWidget);

    final sessionId =
        (tester.state(find.byType(SessionStubScreen)) as dynamic)
            .debugSessionIdForTest as String;

    await tester.tap(find.text('Teacher exit'));
    await pumpFrames(tester);
    await tester.enterText(find.byType(TextField), '1234');
    await tester.tap(find.text('Unlock'));
    await pumpFrames(tester);

    expect(find.text('Teacher PIN'), findsNothing);
    expect(find.text('Aarav Sharma'), findsNothing);
    expect(find.text('Launch'), findsOneWidget);

    final events = await db.eventsForSession(sessionId);
    expect(events.map((e) => e.eventType),
        ['session_started', 'session_aborted']);
    expect(events.last.tMs, greaterThanOrEqualTo(events.first.tMs));
  });
}
