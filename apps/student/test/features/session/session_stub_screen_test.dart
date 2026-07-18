import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
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

Widget _app() {
  return ProviderScope(
    overrides: [pinServiceProvider.overrideWithValue(_FakePinService())],
    child: const MaterialApp(home: SessionStubScreen(args: _args)),
  );
}

void main() {
  testWidgets('shows the confirmed student name', (tester) async {
    await tester.pumpWidget(_app());
    expect(find.text('Aarav Sharma'), findsOneWidget);
  });

  testWidgets('system back does not leave the session', (tester) async {
    await tester.pumpWidget(_app());

    final dynamic widgetsAppState = tester.state(find.byType(WidgetsApp));
    await widgetsAppState.didPopRoute();
    await tester.pumpAndSettle();

    // Still on the session screen — back opened the PIN prompt instead.
    expect(find.text('Aarav Sharma'), findsOneWidget);
    expect(find.text('Teacher PIN'), findsOneWidget);
  });

  testWidgets('wrong PIN keeps the session locked', (tester) async {
    await tester.pumpWidget(_app());

    await tester.tap(find.text('Teacher exit'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '9999');
    await tester.tap(find.text('Unlock'));
    await tester.pumpAndSettle();

    expect(find.text('Wrong PIN'), findsOneWidget);
    expect(find.text('Aarav Sharma'), findsOneWidget);
  });

  testWidgets('correct PIN unlocks and leaves the session screen',
      (tester) async {
    // Push the session screen onto a base route so the unlock pop has
    // somewhere to return to — mirroring real navigation.
    await tester.pumpWidget(
      ProviderScope(
        overrides: [pinServiceProvider.overrideWithValue(_FakePinService())],
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
    await tester.pumpAndSettle();
    expect(find.text('Aarav Sharma'), findsOneWidget);

    await tester.tap(find.text('Teacher exit'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '1234');
    await tester.tap(find.text('Unlock'));
    await tester.pumpAndSettle();

    expect(find.text('Teacher PIN'), findsNothing);
    expect(find.text('Aarav Sharma'), findsNothing);
    expect(find.text('Launch'), findsOneWidget);
  });
}
