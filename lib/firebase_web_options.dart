import 'package:firebase_core/firebase_core.dart';

/// Firebase config for the web app. These values identify the project; they
/// are public by design (every visitor's browser receives them). Access is
/// controlled by Firestore rules and Auth authorized domains.
const firebaseWebOptions = FirebaseOptions(
  apiKey: 'AIzaSyDgyZqTGNLH0xlLA1eJNWXRFXHP_Ui8HA8',
  appId: '1:228178654481:web:805fc6114848df2cd248b0',
  messagingSenderId: '228178654481',
  projectId: 'school-inventory-homilabs',
  authDomain: 'school-inventory-homilabs.firebaseapp.com',
  storageBucket: 'school-inventory-homilabs.firebasestorage.app',
);
