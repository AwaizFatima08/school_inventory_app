import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/auth/sign_in_screen.dart';
import '../features/common/ui_helpers.dart';
import '../features/home/home_shell.dart';
import '../features/onboarding/onboarding_screens.dart';
import 'providers.dart';

class SchoolInventoryApp extends StatelessWidget {
  const SchoolInventoryApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'School Inventory',
      debugShowCheckedModeBanner: false,
      theme: _theme(Brightness.light),
      darkTheme: _theme(Brightness.dark),
      home: const _SessionGate(),
    );
  }

  static ThemeData _theme(Brightness b) => ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2E7D32),
          brightness: b,
        ),
        inputDecorationTheme: const InputDecorationTheme(
          border: UnderlineInputBorder(),
        ),
      );
}

/// Shows the right top-level screen for where the user is in onboarding.
class _SessionGate extends ConsumerWidget {
  const _SessionGate();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watch(sessionProvider).when(
          loading: () => const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => Scaffold(
            body: EmptyState(
              icon: Icons.cloud_off,
              message: 'Could not connect.\n$e',
            ),
          ),
          data: (s) => switch (s) {
            SignedOut() => const SignInScreen(),
            NoSchool() => const CreateOrJoinScreen(),
            AwaitingApproval(:final orgId, :final member) =>
              AwaitingApprovalScreen(orgId: orgId, requestedRole: member.requestedRole),
            AccessDisabled(:final orgId) => AccessDisabledScreen(orgId: orgId),
            ActiveSession() => const HomeShell(),
          },
        );
  }
}
