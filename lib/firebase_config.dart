import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

class ConvieneFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    if (defaultTargetPlatform == TargetPlatform.android) return android;
    throw UnsupportedError(
      'Firebase no esta configurado para esta plataforma.',
    );
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyBUCLnStuDoXgO4m9J9wTOQc2jFog6TSaA',
    appId: '1:473746769200:web:13aef6b388463a5d7c34f5',
    messagingSenderId: '473746769200',
    projectId: 'conviene-87c27',
    authDomain: 'conviene-87c27.firebaseapp.com',
    storageBucket: 'conviene-87c27.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBUCLnStuDoXgO4m9J9wTOQc2jFog6TSaA',
    appId: '1:473746769200:android:bfba83b7aafb34057c34f5',
    messagingSenderId: '473746769200',
    projectId: 'conviene-87c27',
    storageBucket: 'conviene-87c27.firebasestorage.app',
  );
}
