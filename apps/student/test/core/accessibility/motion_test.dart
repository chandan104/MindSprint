import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mindsprint_student/core/accessibility/motion.dart';

void main() {
  testWidgets('reducedMotion reflects MediaQuery.disableAnimations',
      (tester) async {
    late bool normal, reduced;
    await tester.pumpWidget(MaterialApp(
      home: Builder(builder: (context) {
        normal = reducedMotion(context);
        return const SizedBox();
      }),
    ));
    expect(normal, isFalse);

    await tester.pumpWidget(MaterialApp(
      home: MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: Builder(builder: (context) {
          reduced = reducedMotion(context);
          return const SizedBox();
        }),
      ),
    ));
    expect(reduced, isTrue);
  });
}
