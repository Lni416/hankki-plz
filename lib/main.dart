import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app/router.dart';
import 'core/theme/app_theme.dart';
import 'providers/auth_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  bool firebaseReady = false;
  try {
    await Firebase.initializeApp();
    firebaseReady = true;
  } catch (e) {
    // Firebase 설정 파일(google-services.json / GoogleService-Info.plist)이
    // 아직 없으면 목 데이터 모드로 실행됩니다.
    debugPrint('[hankki-plz] Firebase not configured — running in mock mode: $e');
  }

  runApp(
    ProviderScope(
      overrides: [
        firebaseAvailableProvider.overrideWithValue(firebaseReady),
      ],
      child: const HankkiApp(),
    ),
  );
}

class HankkiApp extends StatelessWidget {
  const HankkiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: '한끼를 부탁해',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      routerConfig: appRouter,
    );
  }
}
