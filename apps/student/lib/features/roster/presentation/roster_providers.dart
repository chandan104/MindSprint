import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/remote/supabase_client_provider.dart';
import '../data/roster_repository_impl.dart';
import '../domain/roster_models.dart';
import '../domain/roster_repository.dart';

final rosterRepositoryProvider = Provider<RosterRepository>((ref) {
  return SupabaseRosterRepository(ref.watch(supabaseClientProvider));
});

final myClassesProvider = FutureProvider.autoDispose<List<SchoolClass>>((ref) {
  return ref.watch(rosterRepositoryProvider).myClasses();
});

final studentsProvider =
    FutureProvider.autoDispose.family<List<Student>, String>((ref, classId) {
  return ref.watch(rosterRepositoryProvider).studentsInClass(classId);
});
