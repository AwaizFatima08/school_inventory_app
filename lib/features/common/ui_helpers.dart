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

/// Asks for a short note. The dialog owns its text controller, so it is
/// disposed only after the closing animation (disposing it from the caller
/// while the route was still animating crashed the app).
Future<String?> askText(
  BuildContext context, {
  required String title,
  String label = 'Note (optional)',
  bool required = false,
}) =>
    showDialog<String>(
      context: context,
      builder: (_) => _TextDialog(title: title, label: label, required: required),
    );

class _TextDialog extends StatefulWidget {
  const _TextDialog({
    required this.title,
    required this.label,
    required this.required,
  });
  final String title;
  final String label;
  final bool required;

  @override
  State<_TextDialog> createState() => _TextDialogState();
}

class _TextDialogState extends State<_TextDialog> {
  final _controller = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final t = _controller.text.trim();
    if (widget.required && t.length < 3) {
      setState(() => _error = 'Please write at least 3 letters');
      return;
    }
    Navigator.pop(context, t);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLines: 3,
        decoration: InputDecoration(labelText: widget.label, errorText: _error),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: const Text('OK')),
      ],
    );
  }
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
