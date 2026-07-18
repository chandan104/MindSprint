import 'package:flutter_test/flutter_test.dart';
import 'package:mindsprint_student/core/errors/failures.dart';
import 'package:mindsprint_student/features/auth/domain/startup_gate.dart';
import 'package:mocktail/mocktail.dart';

class _MockGateRepository extends Mock implements PlatformGateRepository {}

void main() {
  group('compareVersions', () {
    test('orders dotted numeric versions correctly', () {
      expect(compareVersions('0.1.0', '0.1.0'), 0);
      expect(compareVersions('0.1.0', '0.2.0'), lessThan(0));
      expect(compareVersions('1.0.0', '0.9.9'), greaterThan(0));
      expect(compareVersions('0.10.0', '0.9.0'), greaterThan(0),
          reason: 'numeric, not lexicographic');
      expect(compareVersions('1.0', '1.0.0'), 0,
          reason: 'missing segments are zero');
      expect(compareVersions('1.0.1', '1.0'), greaterThan(0));
    });
  });

  group('StartupGate', () {
    late _MockGateRepository repository;

    setUp(() {
      repository = _MockGateRepository();
      when(() => repository.featureFlags())
          .thenAnswer((_) async => {'memory_module': true, 'maths_module': false});
    });

    test('passes when app version meets the minimum and returns flags',
        () async {
      when(() => repository.minimumSupportedVersion())
          .thenAnswer((_) async => '0.1.0');
      final gate = StartupGate(repository: repository, appVersion: '0.1.0');

      final state = await gate.check();
      expect(state.flag('memory_module'), isTrue);
      expect(state.flag('maths_module'), isFalse);
      expect(state.flag('nonexistent'), isFalse);
    });

    test('blocks outdated app versions', () async {
      when(() => repository.minimumSupportedVersion())
          .thenAnswer((_) async => '0.2.0');
      final gate = StartupGate(repository: repository, appVersion: '0.1.9');

      expect(gate.check(), throwsA(isA<VersionBlockedFailure>()));
    });

    test('passes when no version rows exist (fresh environment)', () async {
      when(() => repository.minimumSupportedVersion())
          .thenAnswer((_) async => null);
      final gate = StartupGate(repository: repository, appVersion: '0.0.1');

      final state = await gate.check();
      expect(state.featureFlags, isNotEmpty);
    });
  });
}
