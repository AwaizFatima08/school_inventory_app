import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/result.dart';
import '../../domain/models.dart';

/// Runs a repository action, shows a snackbar for the outcome, and returns
/// whether it succeeded. Guards `mounted` after the await.
Future<bool> runAction(
  BuildContext context,
  Future<Result<Object?>> Function() action, {
  String? success,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  final result = await action();
  switch (result) {
    case Ok():
      if (success != null) {
        messenger.showSnackBar(SnackBar(content: Text(success)));
      }
      return true;
    case Err(:final failure):
      messenger.showSnackBar(SnackBar(
        content: Text(failure.message),
        backgroundColor: Colors.red.shade700,
      ));
      return false;
  }
}

final _dateTime = DateFormat('d MMM yyyy, h:mm a');
final _date = DateFormat('d MMM yyyy');

String formatDateTime(DateTime? d) => d == null ? '—' : _dateTime.format(d);
String formatDate(DateTime? d) => d == null ? '—' : _date.format(d);

Color statusColor(DocStatus s, ColorScheme c) => switch (s) {
      DocStatus.pending => Colors.orange.shade800,
      DocStatus.approved => c.primary,
      DocStatus.issued => Colors.green.shade700,
      DocStatus.rejected => Colors.red.shade700,
      DocStatus.cancelled => Colors.grey.shade600,
    };

/// A small coloured status label.
class StatusChip extends StatelessWidget {
  const StatusChip(this.status, {super.key});
  final DocStatus status;

  @override
  Widget build(BuildContext context) {
    final color = statusColor(status, Theme.of(context).colorScheme);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status.label,
        style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 12),
      ),
    );
  }
}

/// Centered message for empty lists.
class EmptyState extends StatelessWidget {
  const EmptyState({required this.icon, required this.message, super.key});
  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

Future<String?> askText(
  BuildContext context, {
  required String title,
  String label = 'Note (optional)',
  bool required = false,
}) {
  final controller = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: controller,
        autofocus: true,
        maxLines: 3,
        decoration: InputDecoration(labelText: label),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final t = controller.text.trim();
            if (required && t.length < 3) return;
            Navigator.pop(ctx, t);
          },
          child: const Text('OK'),
        ),
      ],
    ),
  ).whenComplete(controller.dispose);
}

Future<bool> confirm(BuildContext context, String title, String message) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('No'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Yes'),
        ),
      ],
    ),
  );
  return ok ?? false;
}
