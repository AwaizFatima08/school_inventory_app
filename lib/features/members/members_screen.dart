import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../domain/models.dart';
import '../../domain/roles.dart';
import '../common/async_view.dart';
import '../common/ui_helpers.dart';

/// Admin: approve join requests, change roles (e.g. when the incharge
/// rotates), grant admin, turn access off.
class MembersScreen extends ConsumerWidget {
  const MembersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final org = ref.watch(currentOrgProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Users & roles')),
      body: AsyncView(
        value: ref.watch(membersProvider),
        builder: (members) {
          final pending = members.where((m) => m.status == MemberStatus.pending);
          final others = members.where((m) => m.status != MemberStatus.pending);
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _JoinCodeCard(code: org.joinCode),
              const SizedBox(height: 16),
              Text('Requests (${pending.length})',
                  style: Theme.of(context).textTheme.titleMedium),
              if (pending.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text('No one is waiting.'),
                ),
              for (final m in pending) _MemberTile(member: m),
              const SizedBox(height: 16),
              Text('Members', style: Theme.of(context).textTheme.titleMedium),
              for (final m in others) _MemberTile(member: m),
            ],
          );
        },
      ),
    );
  }
}

class _JoinCodeCard extends StatelessWidget {
  const _JoinCodeCard({required this.code});
  final String code;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title: const Text('School code'),
        subtitle: const Text('New supervisors / incharges sign up in the app, '
            'tap "Join your school" and type this code. You then approve them here.'),
        trailing: TextButton.icon(
          icon: const Icon(Icons.copy),
          label: Text(code, style: const TextStyle(fontSize: 18, letterSpacing: 2)),
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: code));
            if (context.mounted) {
              ScaffoldMessenger.of(context)
                  .showSnackBar(const SnackBar(content: Text('Code copied.')));
            }
          },
        ),
      ),
    );
  }
}

class _MemberTile extends ConsumerWidget {
  const _MemberTile({required this.member});
  final Member member;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = member;
    final me = ref.watch(currentMemberProvider);
    final subtitle = switch (m.status) {
      MemberStatus.pending => 'Asks to be: ${m.requestedRole?.label ?? '—'}\n${m.email}',
      MemberStatus.disabled => 'Access off · ${m.email}',
      MemberStatus.active => '${m.role.label}${m.isAdmin ? ' · Admin' : ''}\n${m.email}',
    };
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(child: Text(m.displayName.characters.first)),
      title: Text(m.displayName + (m.uid == me.uid ? ' (you)' : '')),
      subtitle: Text(subtitle),
      isThreeLine: true,
      trailing: const Icon(Icons.edit),
      onTap: () => showDialog<void>(
        context: context,
        builder: (_) => _EditMemberDialog(member: m, isSelf: m.uid == me.uid),
      ),
    );
  }
}

class _EditMemberDialog extends ConsumerStatefulWidget {
  const _EditMemberDialog({required this.member, required this.isSelf});
  final Member member;
  final bool isSelf;

  @override
  ConsumerState<_EditMemberDialog> createState() => _EditMemberDialogState();
}

class _EditMemberDialogState extends ConsumerState<_EditMemberDialog> {
  late Role _role = widget.member.status == MemberStatus.pending
      ? widget.member.requestedRole ?? Role.supervisor
      : widget.member.role;
  late bool _admin = widget.member.isAdmin;
  late bool _active = widget.member.status != MemberStatus.disabled;
  bool _busy = false;

  bool get _pending => widget.member.status == MemberStatus.pending;

  Future<void> _save() async {
    setState(() => _busy = true);
    final org = ref.read(currentOrgProvider);
    final ok = await runAction(
      context,
      () => ref.read(accountRepositoryProvider).updateMember(
            orgId: org.id,
            memberUid: widget.member.uid,
            role: _role,
            isAdmin: _admin,
            status: _active ? MemberStatus.active : MemberStatus.disabled,
          ),
      success: _pending ? 'Approved.' : 'Saved.',
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) Navigator.of(context).pop();
  }

  Future<void> _remove() async {
    final org = ref.read(currentOrgProvider);
    final ok = await runAction(
      context,
      () => ref.read(accountRepositoryProvider).removeMember(org.id, widget.member.uid),
      success: _pending ? 'Request declined.' : 'Removed.',
    );
    if (ok && mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_pending ? 'Approve ${widget.member.displayName}?' : widget.member.displayName),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonFormField<Role>(
            initialValue: _role,
            decoration: const InputDecoration(labelText: 'Role'),
            items: [
              for (final r in Role.values) DropdownMenuItem(value: r, child: Text(r.label)),
            ],
            onChanged: (r) => setState(() => _role = r ?? _role),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Admin'),
            subtitle: const Text('Can approve users and change roles'),
            value: _admin,
            onChanged: widget.isSelf ? null : (v) => setState(() => _admin = v),
          ),
          if (!_pending)
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Access on'),
              value: _active,
              onChanged: widget.isSelf ? null : (v) => setState(() => _active = v),
            ),
        ],
      ),
      actions: [
        if (!widget.isSelf)
          TextButton(
            onPressed: _busy ? null : _remove,
            child: Text(_pending ? 'Decline' : 'Remove'),
          ),
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: _busy ? null : _save,
          child: Text(_pending ? 'Approve' : 'Save'),
        ),
      ],
    );
  }
}
