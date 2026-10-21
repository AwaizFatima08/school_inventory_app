import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../domain/models.dart';
import '../../domain/roles.dart';
import '../common/async_view.dart';
import '../common/ui_helpers.dart';
import '../items/item_detail_screen.dart';

/// Janitorial staff records (they do not sign in).
class StaffScreen extends ConsumerWidget {
  const StaffScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(currentMemberProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Janitorial staff')),
      floatingActionButton: me.can(Capability.manageStaff)
          ? FloatingActionButton.extended(
              icon: const Icon(Icons.person_add_alt),
              label: const Text('Add staff'),
              onPressed: () => _openForm(context, null),
            )
          : null,
      body: AsyncView(
        value: ref.watch(staffProvider),
        builder: (staff) => staff.isEmpty
            ? const EmptyState(
                icon: Icons.people_outline,
                message: 'No staff yet. Add each janitorial staff member so '
                    'their demand slips can be entered.')
            : ListView.separated(
                padding: const EdgeInsets.only(bottom: 88),
                itemCount: staff.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (_, i) {
                  final s = staff[i];
                  return ListTile(
                    leading: CircleAvatar(child: Text(s.name.characters.first)),
                    title: Text(s.name + (s.active ? '' : ' (inactive)')),
                    subtitle: Text([
                      if (s.employeeNo.isNotEmpty) 'No. ${s.employeeNo}',
                      if (s.dutyArea.isNotEmpty) s.dutyArea,
                    ].join(' · ')),
                    trailing: me.can(Capability.manageStaff)
                        ? IconButton(
                            tooltip: 'Edit',
                            icon: const Icon(Icons.edit),
                            onPressed: () => _openForm(context, s),
                          )
                        : null,
                    onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
                      builder: (_) => StaffHistoryScreen(staff: s),
                    )),
                  );
                },
              ),
      ),
    );
  }

  static void _openForm(BuildContext context, StaffMember? s) =>
      showDialog<void>(context: context, builder: (_) => StaffFormDialog(staff: s));
}

/// Everything issued to one staff member.
class StaffHistoryScreen extends ConsumerWidget {
  const StaffHistoryScreen({required this.staff, super.key});
  final StaffMember staff;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: Text(staff.name)),
      body: AsyncView(
        value: ref.watch(staffLedgerProvider(staff.id)),
        builder: (entries) => entries.isEmpty
            ? const EmptyState(icon: Icons.history, message: 'Nothing issued yet.')
            : ListView.separated(
                itemCount: entries.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (_, i) => LedgerTile(entry: entries[i], showItem: true),
              ),
      ),
    );
  }
}

/// Add / edit a staff member.
class StaffFormDialog extends ConsumerStatefulWidget {
  const StaffFormDialog({this.staff, super.key});
  final StaffMember? staff;

  @override
  ConsumerState<StaffFormDialog> createState() => _StaffFormDialogState();
}

class _StaffFormDialogState extends ConsumerState<StaffFormDialog> {
  late final _name = TextEditingController(text: widget.staff?.name);
  late final _no = TextEditingController(text: widget.staff?.employeeNo);
  late final _phone = TextEditingController(text: widget.staff?.phone);
  late final _area = TextEditingController(text: widget.staff?.dutyArea);
  late bool _active = widget.staff?.active ?? true;
  bool _busy = false;

  @override
  void dispose() {
    for (final c in [_name, _no, _phone, _area]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) return;
    setState(() => _busy = true);
    final ok = await runAction(
      context,
      () => ref.read(inventoryRepositoryProvider).saveStaff(
            id: widget.staff?.id,
            name: _name.text,
            employeeNo: _no.text,
            phone: _phone.text,
            dutyArea: _area.text,
            active: _active,
            by: ref.read(actorProvider),
          ),
      success: 'Saved.',
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.staff == null ? 'Add staff member' : 'Edit staff member'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            TextField(
              controller: _no,
              decoration: const InputDecoration(labelText: 'Employee no. (optional)'),
            ),
            TextField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Phone (optional)'),
            ),
            TextField(
              controller: _area,
              decoration: const InputDecoration(
                labelText: 'Duty area (optional)',
                hintText: 'e.g. Junior block washrooms',
              ),
            ),
            if (widget.staff != null)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Active'),
                value: _active,
                onChanged: (v) => setState(() => _active = v),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(onPressed: _busy ? null : _save, child: const Text('Save')),
      ],
    );
  }
}
