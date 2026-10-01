import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../firebase_options.dart';

@pragma('vm:entry-point')
Future<void> firebaseBackgroundMessage(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}

class FirebaseServices {
  static bool ready = false;
  static bool get mobile =>
      !kIsWeb &&
      [
        TargetPlatform.android,
        TargetPlatform.iOS,
      ].contains(defaultTargetPlatform);
  static Future<void> initialize() async {
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      ready = true;
      FirebaseFirestore.instance.settings = const Settings(
        persistenceEnabled: false,
      );
      if (mobile) {
        FirebaseMessaging.onBackgroundMessage(firebaseBackgroundMessage);
        FlutterError.onError = (details) {
          FlutterError.presentError(details);
          FirebaseCrashlytics.instance.recordFlutterFatalError(details);
        };
        PlatformDispatcher.instance.onError = (error, stack) {
          FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
          return true;
        };
      }
    } on UnsupportedError {
      ready = false;
    } catch (_) {
      ready = false;
    }
  }

  static Future<String> googleToken() async {
    if (!ready) throw StateError('Firebase chưa được cấu hình cho ứng dụng.');
    UserCredential result;
    if (kIsWeb) {
      result = await FirebaseAuth.instance.signInWithPopup(
        GoogleAuthProvider(),
      );
    } else {
      await GoogleSignIn.instance.initialize();
      final account = await GoogleSignIn.instance.authenticate();
      result = await FirebaseAuth.instance.signInWithCredential(
        GoogleAuthProvider.credential(idToken: account.authentication.idToken),
      );
    }
    final token = await result.user?.getIdToken(true);
    if (token == null) throw StateError('Không nhận được phiên Google.');
    return token;
  }

  static Future<String> upload(Uint8List bytes, {required bool png}) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (!ready || uid == null || !uid.startsWith('rental_')) {
      throw StateError('Hãy kết nối Firebase trong mục Tài khoản trước.');
    }
    if (bytes.length >= 3 * 1024 * 1024) {
      throw StateError('Ảnh phải nhỏ hơn 3 MB.');
    }
    final ref = FirebaseStorage.instance.ref(
      'uploads/$uid/${DateTime.now().microsecondsSinceEpoch}.${png ? 'png' : 'jpg'}',
    );
    await ref.putData(
      bytes,
      SettableMetadata(contentType: png ? 'image/png' : 'image/jpeg'),
    );
    return ref.getDownloadURL();
  }
}
