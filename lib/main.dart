import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';

/// Run with `--dart-define=USE_EMULATOR=true` to use the local Firebase
/// emulators: 10.0.2.2 from an Android emulator (default), or
/// `--dart-define=EMULATOR_HOST=127.0.0.1` on a real phone after
/// `adb reverse tcp:9099 tcp:9099` and `adb reverse tcp:8086 tcp:8086`.
const _useEmulator = bool.fromEnvironment('USE_EMULATOR');
const _emulatorHost = String.fromEnvironment('EMULATOR_HOST', defaultValue: '10.0.2.2');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Android reads its config from android/app/google-services.json.
  await Firebase.initializeApp();
  if (_useEmulator) {
    // automaticHostMapping would rewrite 127.0.0.1 to 10.0.2.2, which only
    // works on the Android emulator. Real phones use `adb reverse` + 127.0.0.1.
    await FirebaseAuth.instance
        .useAuthEmulator(_emulatorHost, 9099, automaticHostMapping: false);
    FirebaseFirestore.instance
        .useFirestoreEmulator(_emulatorHost, 8086, automaticHostMapping: false);
  }
  runApp(const ProviderScope(child: SchoolInventoryApp()));
}
