import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Compact whole-number field with − / + buttons, clamped to [0, max].
class QtyField extends StatefulWidget {
  const QtyField({
    required this.value,
    required this.onChanged,
    this.max,
    super.key,
  });

  final int value;
  final int? max;
  final ValueChanged<int> onChanged;

  @override
  State<QtyField> createState() => _QtyFieldState();
}

class _QtyFieldState extends State<QtyField> {
  late final _controller = TextEditingController(text: '${widget.value}');

  @override
  void didUpdateWidget(QtyField old) {
    super.didUpdateWidget(old);
    if (int.tryParse(_controller.text) != widget.value) {
      _controller.text = '${widget.value}';
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  int _clamp(int v) {
    final upper = widget.max;
    if (v < 0) return 0;
    return upper != null && v > upper ? upper : v;
  }

  void _set(int v) {
    final c = _clamp(v);
    if (c != widget.value) widget.onChanged(c);
    if (int.tryParse(_controller.text) != c) _controller.text = '$c';
  }

  @override
  Widget build(BuildContext context) {
    final max = widget.max;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: 'Less',
          icon: const Icon(Icons.remove_circle_outline),
          onPressed: widget.value > 0 ? () => _set(widget.value - 1) : null,
        ),
        SizedBox(
          width: 52,
          child: TextField(
            controller: _controller,
            textAlign: TextAlign.center,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(
              isDense: true,
              contentPadding: EdgeInsets.symmetric(vertical: 8),
            ),
            onChanged: (t) {
              final v = int.tryParse(t);
              if (v == null) return;
              final c = _clamp(v);
              if (c != v) _controller.text = '$c';
              if (c != widget.value) widget.onChanged(c);
            },
          ),
        ),
        IconButton(
          tooltip: 'More',
          icon: const Icon(Icons.add_circle_outline),
          onPressed: max == null || widget.value < max
              ? () => _set(widget.value + 1)
              : null,
        ),
      ],
    );
  }
}
