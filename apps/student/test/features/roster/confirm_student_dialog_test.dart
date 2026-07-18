import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mindsprint_student/features/roster/domain/roster_models.dart';
import 'package:mindsprint_student/features/roster/presentation/confirm_student_dialog.dart';

const _student = Student(
  id: 'st1',
  classId: 'c1',
  fullName: 'Diya Patel',
  rollNumber: '4A-02',
);

Widget _host(void Function(bool) onResult) {
  return MaterialApp(
    home: Scaffold(
      body: Builder(
        builder: (context) => Center(
          child: FilledButton(
            onPressed: () async {
              onResult(await showConfirmStudentDialog(context, _student));
            },
            child: const Text('Open'),
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('shows student identity and returns true on Start',
      (tester) async {
    bool? result;
    await tester.pumpWidget(_host((r) => result = r));

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.text('Diya Patel'), findsOneWidget);
    expect(find.text('Roll 4A-02'), findsOneWidget);

    await tester.tap(find.text('Start'));
    await tester.pumpAndSettle();
    expect(result, isTrue);
  });

  testWidgets('returns false on Cancel', (tester) async {
    bool? result;
    await tester.pumpWidget(_host((r) => result = r));

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(result, isFalse);
  });

  testWidgets('dismissing via barrier returns false', (tester) async {
    bool? result;
    await tester.pumpWidget(_host((r) => result = r));

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();

    expect(result, isFalse);
  });
}
