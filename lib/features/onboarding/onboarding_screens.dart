import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../domain/roles.dart';
import '../common/ui_helpers.dart';

/// After sign-in, before belonging to a school: create one or join one.
class CreateOrJoinScreen extends ConsumerStatefulWidget {
  const CreateOrJoinScreen({super.key});

  @override
  ConsumerState<CreateOrJoinScreen> createState() => _CreateOrJoinScreenState();
}

class _CreateOrJoinScreenState extends ConsumerState<CreateOrJoinScreen> {
  final _schoolName = TextEditingController();
  final _code = TextEditingController();
  bool _seed = true;
  Role _role = Role.supervisor;
  bool _busy = false;

  @override
  void dispose() {
    _schoolName.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    if (_schoolName.text.trim().length < 2) return;
    setState(() => _busy = true);
    await runAction(
      context,
      () => ref.read(accountRepositoryProvider).createSchool(
            schoolName: _schoolName.text,
            seedDefaultItems: _seed,
          ),
    );
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _join() async {
    if (_code.text.trim().length != 6) return;
    setState(() => _busy = true);
    await runAction(
      context,
      () => ref
          .read(accountRepositoryProvider)
          .requestToJoin(joinCode: _code.text, requestedRole: _role),
    );
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Get started'),
        actions: [
          IconButton(
            tooltip: 'Sign out',
            icon: const Icon(Icons.logout),
            onPressed: () => ref.read(accountRepositoryProvider).signOut(),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('Join your school', style: t.titleLarge),
          const SizedBox(height: 4),
          const Text('Ask your admin for the 6-letter school code. '
              'The admin approves your request.'),
          const SizedBox(height: 12),
          TextField(
            controller: _code,
            textCapitalization: TextCapitalization.characters,
            maxLength: 6,
            decoration: const InputDecoration(labelText: 'School code'),
          ),
          DropdownButtonFormField<Role>(
            initialValue: _role,
            decoration: const InputDecoration(labelText: 'I am the'),
            items: [
              for (final r in Role.values)
                DropdownMenuItem(value: r, child: Text(r.label)),
            ],
            onChanged: (r) => setState(() => _role = r ?? Role.supervisor),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _busy ? null : _join,
            child: const Text('Request to join'),
          ),
          const Divider(height: 48),
          Text('Or set up a new school', style: t.titleLarge),
          const SizedBox(height: 4),
          const Text('You become the Janitorial Incharge and the admin who '
              'approves new users.'),
          const SizedBox(height: 12),
          TextField(
            controller: _schoolName,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'School name',
              hintText: 'e.g. Fatima Fertilizer School',
            ),
          ),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: _seed,
            onChanged: (v) => setState(() => _seed = v ?? true),
            title: const Text('Add the standard janitorial item list'),
            subtitle: const Text('Soap, mops, Harpic, bleach, brushes… '
                'You can edit or add items later.'),
          ),
          OutlinedButton(
            onPressed: _busy ? null : _create,
            child: const Text('Create school'),
          ),
        ],
      ),
    );
  }
}

/// Waiting for the admin to approve the join request.
class AwaitingApprovalScreen extends ConsumerWidget {
  const AwaitingApprovalScreen({
    required this.orgId,
    required this.requestedRole,
    super.key,
  });
  final String orgId;
  final Role? requestedRole;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.read(accountRepositoryProvider);
    return _InfoScreen(
      icon: Icons.hourglass_top,
      title: 'Waiting for approval',
      message: 'Your request to join as '
          '${requestedRole?.label ?? 'a member'} was sent. '
          'The school admin will approve it. This screen updates by itself.',
      actions: [
        OutlinedButton(
          onPressed: () => runAction(
            context,
            () => repo.leaveSchool(orgId, isPending: true),
          ),
          child: const Text('Withdraw request'),
        ),
        TextButton(onPressed: repo.signOut, child: const Text('Sign out')),
      ],
    );
  }
}

/// The admin disabled this account.
class AccessDisabledScreen extends ConsumerWidget {
  const AccessDisabledScreen({required this.orgId, super.key});
  final String orgId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.read(accountRepositoryProvider);
    return _InfoScreen(
      icon: Icons.block,
      title: 'Access turned off',
      message: 'The school admin has turned off your access. '
          'Contact them if this is a mistake.',
      actions: [
        OutlinedButton(
          onPressed: () => runAction(
            context,
            () => repo.leaveSchool(orgId, isPending: false),
          ),
          child: const Text('Join a different school'),
        ),
        TextButton(onPressed: repo.signOut, child: const Text('Sign out')),
      ],
    );
  }
}

class _InfoScreen extends StatelessWidget {
  const _InfoScreen({
    required this.icon,
    required this.title,
    required this.message,
    required this.actions,
  });
  final IconData icon;
  final String title;
  final String message;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 64, color: Theme.of(context).colorScheme.primary),
                const SizedBox(height: 16),
                Text(title, style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 8),
                Text(message, textAlign: TextAlign.center),
                const SizedBox(height: 24),
                ...actions,
              ],
            ),
          ),
        ),
      ),
    );
  }
}
