import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/failures.dart';
import '../domain/roster_models.dart';
import '../domain/roster_repository.dart';

class SupabaseRosterRepository implements RosterRepository {
  final SupabaseClient _client;
  SupabaseRosterRepository(this._client);

  @override
  Future<List<SchoolClass>> myClasses() async {
    final teacherId = _client.auth.currentUser?.id;
    if (teacherId == null) throw const AuthFailure('Not signed in.');
    try {
      // RLS already scopes to the teacher's school; the inner join narrows to
      // classes explicitly assigned to this teacher.
      final rows = await _client
          .from('classes')
          .select('id, name, grade, teacher_classes!inner(teacher_id)')
          .eq('teacher_classes.teacher_id', teacherId)
          .order('grade')
          .order('name');
      return [for (final row in rows) SchoolClass.fromJson(row)];
    } on SocketException {
      throw const NetworkFailure();
    } on PostgrestException catch (e) {
      throw UnknownFailure('Could not load classes: ${e.message}');
    }
  }

  @override
  Future<List<Student>> studentsInClass(String classId) async {
    try {
      final rows = await _client
          .from('students')
          .select('id, class_id, school_id, full_name, roll_number')
          .eq('class_id', classId)
          .eq('is_active', true)
          .order('roll_number')
          .order('full_name');
      return [for (final row in rows) Student.fromJson(row)];
    } on SocketException {
      throw const NetworkFailure();
    } on PostgrestException catch (e) {
      throw UnknownFailure('Could not load students: ${e.message}');
    }
  }
}
