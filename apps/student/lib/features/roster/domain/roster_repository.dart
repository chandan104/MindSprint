import 'roster_models.dart';

abstract interface class RosterRepository {
  /// Classes assigned to the signed-in teacher (via teacher_classes).
  Future<List<SchoolClass>> myClasses();

  /// Active students of one class, ordered by roll number.
  Future<List<Student>> studentsInClass(String classId);
}
