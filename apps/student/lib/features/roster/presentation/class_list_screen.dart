import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/failures.dart';
import '../../../core/router/app_router.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../sync/application/sync_service.dart';
import 'roster_providers.dart';

class ClassListScreen extends ConsumerStatefulWidget {
  const ClassListScreen({super.key});

  @override
  ConsumerState<ClassListScreen> createState() => _ClassListScreenState();
}

class _ClassListScreenState extends ConsumerState<ClassListScreen> {
  @override
  void initState() {
    super.initState();
    // Opportunistic retry every time the teacher lands here — the natural
    // between-students moment in the classroom flow.
    Future.microtask(_retry);
  }

  Future<void> _retry() async {
    await ref.read(syncServiceProvider).retryPending();
    if (mounted) ref.invalidate(pendingUploadCountProvider);
  }

  @override
  Widget build(BuildContext context) {
    final classes = ref.watch(myClassesProvider);
    final pending = ref.watch(pendingUploadCountProvider).value ?? 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Classes'),
        actions: [
          if (pending > 0)
            IconButton(
              tooltip: '$pending session(s) waiting to upload — tap to retry',
              onPressed: _retry,
              icon: Badge(
                label: Text('$pending'),
                child: const Icon(Icons.cloud_upload_outlined),
              ),
            ),
          IconButton(
            tooltip: 'Sign out',
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await ref.read(authRepositoryProvider).signOut();
              if (context.mounted) context.go(AppRoutes.login);
            },
          ),
        ],
      ),
      body: classes.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _RosterError(
          message: error is Failure ? error.message : 'Could not load classes.',
          onRetry: () => ref.invalidate(myClassesProvider),
        ),
        data: (items) => items.isEmpty
            ? const Center(
                child: Text('No classes assigned yet.\nAsk your school admin.',
                    textAlign: TextAlign.center),
              )
            : ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 12),
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final schoolClass = items[index];
                  return Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        child: Text('${schoolClass.grade ?? '–'}'),
                      ),
                      title: Text(schoolClass.name,
                          style: Theme.of(context).textTheme.titleLarge),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () =>
                          context.go(AppRoutes.studentsFor(schoolClass.id)),
                    ),
                  );
                },
              ),
      ),
    );
  }
}

class _RosterError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _RosterError({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          FilledButton(onPressed: onRetry, child: const Text('Try again')),
        ],
      ),
    );
  }
}
