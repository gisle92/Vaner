// lib/push_notifications.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

class PushNotifications {
  static final PushNotifications _instance = PushNotifications._internal();
  factory PushNotifications() => _instance;
  PushNotifications._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  Future<void> init(User user) async {
    // For now we skip push on web – we mainly care about Android/iOS.
    if (kIsWeb) {
      debugPrint("[Push] Web: skipping FCM token registration.");
      return;
    }

    // Ask permission (required on iOS and Android 13+)
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    debugPrint("[Push] Permission: ${settings.authorizationStatus}");

    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      debugPrint("[Push] Notifications denied by user.");
      return;
    }

    // Get initial token
    final token = await _messaging.getToken();
    debugPrint("[Push] FCM token: $token");

    if (token != null) {
      await _saveToken(user.uid, token);
    }

    // Listen for refresh
    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
      debugPrint("[Push] FCM token refreshed: $newToken");
      await _saveToken(user.uid, newToken);
    });

    // Optional: log foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint(
        "[Push] Foreground message: "
        "${message.notification?.title} / ${message.notification?.body}",
      );
    });
  }

  Future<void> _saveToken(String uid, String token) async {
    final devicesRef = FirebaseFirestore.instance
        .collection("users")
        .doc(uid)
        .collection("devices")
        .doc(token); // use token as doc id

    final platform = _platformString();

    await devicesRef.set(
      {
        "token": token,
        "platform": platform,
        "updatedAt": FieldValue.serverTimestamp(),
        "createdAt": FieldValue.serverTimestamp(),
        "enabled": true,
      },
      SetOptions(merge: true),
    );

    debugPrint("[Push] Saved token for $uid on $platform");
  }

  String _platformString() {
    if (kIsWeb) return "web";
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return "android";
      case TargetPlatform.iOS:
        return "ios";
      case TargetPlatform.macOS:
        return "macos";
      case TargetPlatform.windows:
        return "windows";
      case TargetPlatform.linux:
        return "linux";
      default:
        return "unknown";
    }
  }
}
