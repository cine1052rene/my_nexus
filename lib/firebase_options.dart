// File generated for MyNexus Firebase project
// Project: my-nexus-hub
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return web; // fallback
      default:
        return web;
    }
  }

  // Web 설정 (Firebase Console에서 가져온 실제 값)
  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyAv5Kvph7fnPHK3rH_oaSSTC8h2F5Yp7Is',
    appId: '1:397552928960:web:e8e522c8ab844219204525',
    messagingSenderId: '397552928960',
    projectId: 'my-nexus-hub',
    authDomain: 'my-nexus-hub.firebaseapp.com',
    storageBucket: 'my-nexus-hub.firebasestorage.app',
  );

  // Android 설정 — google-services.json 다운로드 후 업데이트 필요
  // Firebase Console > 프로젝트 설정 > 앱 추가 > Android
  // Package name: com.personal.nexus
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyAv5Kvph7fnPHK3rH_oaSSTC8h2F5Yp7Is',
    appId: '1:397552928960:android:PLACEHOLDER',
    messagingSenderId: '397552928960',
    projectId: 'my-nexus-hub',
    storageBucket: 'my-nexus-hub.firebasestorage.app',
  );

  // iOS 설정 — GoogleService-Info.plist 다운로드 후 업데이트 필요
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyAv5Kvph7fnPHK3rH_oaSSTC8h2F5Yp7Is',
    appId: '1:397552928960:ios:PLACEHOLDER',
    messagingSenderId: '397552928960',
    projectId: 'my-nexus-hub',
    storageBucket: 'my-nexus-hub.firebasestorage.app',
    iosBundleId: 'com.personal.nexus',
  );
}
