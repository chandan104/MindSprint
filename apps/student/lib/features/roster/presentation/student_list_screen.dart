import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/failures.dart';
import '../../../core/router/app_router.dart';
import '../../session/domain/session_args.dart';
import '../domain/roster_models.dart';
import 'confirm_student_dialog.dart';
import 'roster_providers.dart';

class StudentListScreen extends ConsumerWidget {
  final String classId;
  const StudentListScreen({super.key, required this.classId});

  Future<void> _startForStudent(
      BuildContext context, WidgetRef ref, Student student) async {
    // Teacher confirmation before every session: on a shared tablet the wrong
    // name here would permanently attribute results to the wrong child.
    final confirmed = await showConfirmStudentDialog(context, student);
    if (confirmed && context.mounted) {
      context.push(
        AppRoutes.setup,
        extra: ConfirmedStudent(
          studentId: student.id,
          studentName: student.fullName,
          classId: student.classId,
          schoolId: student.schoolId,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final students = ref.watch(studentsProvider(classId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Choose a student'),
        leading: BackButton(onPressed: () => context.go(AppRoutes.classes)),
      ),
      body: students.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                error is Failure ? error.message : 'Could not load students.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => ref.invalidate(studentsProvider(classId)),
                child: const Text('Try again'),
              ),
            ],
          ),
        ),
        data: (items) => items.isEmpty
            ? const Center(child: Text('No students in this class yet.'))
            : ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 12),
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final student = items[index];
                  return Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        child: Text(student.fullName.characters.first),
                      ),
                      title: Text(student.fullName,
                          style: Theme.of(context).textTheme.titleLarge),
                      subtitle: student.rollNumber == null
                          ? null
                          : Text('Roll ${student.rollNumber}'),
                      trailing: const Icon(Icons.play_circle_outline, size: 32),
                      onTap: () => _startForStudent(context, ref, student),
                    ),
                  );
                },
              ),
      ),
    );
  }
}
