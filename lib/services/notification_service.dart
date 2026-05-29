import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

/// FCM 초기화 및 토큰 관리
class NotificationService {
  static Future<void> initialize(String uid) async {
    try {
      final messaging = FirebaseMessaging.instance;

      // 알림 권한 요청 (iOS)
      await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      // FCM 토큰 획득 후 Firestore에 저장
      final token = await messaging.getToken();
      if (token != null) {
        await _saveToken(uid, token);
      }

      // 토큰 갱신 시 자동 업데이트
      messaging.onTokenRefresh.listen((newToken) => _saveToken(uid, newToken));

      // 포그라운드 알림 설정 (iOS)
      await messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );
    } catch (e) {
      debugPrint('[FCM] 초기화 실패: $e');
    }
  }

  static Future<void> _saveToken(String uid, String token) async {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .set({'fcmToken': token}, SetOptions(merge: true));
  }
}
