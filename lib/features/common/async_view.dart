import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'ui_helpers.dart';

/// Renders an [AsyncValue] with standard loading and error states.
class AsyncView<T> extends StatelessWidget {
  const AsyncView({required this.value, required this.builder, super.key});
  final AsyncValue<T> value;
  final Widget Function(T data) builder;

  @override
  Widget build(BuildContext context) {
    return value.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) =>
          EmptyState(icon: Icons.cloud_off, message: 'Could not load data.\n$e'),
      data: builder,
    );
  }
}
