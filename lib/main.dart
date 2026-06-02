import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app/router.dart';
import 'core/theme/app_theme.dart';
import 'firebase_options.dart';
import 'providers/auth_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  bool firebaseReady = false;
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
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

class HankkiApp extends ConsumerWidget {
  const HankkiApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final firebaseAvailable = ref.watch(firebaseAvailableProvider);

    // ── 중앙 Auth 게이트 ──────────────────────────────────────────────
    // 웹 새로고침 시 Firebase Auth 복원이 끝나기 전에 화면(과 provider)이
    // 먼저 mount되면 Firestore 접근이 권한 오류로 실패해 데이터가 빈 채로 굳는다.
    // auth 상태가 처음으로 확정(non-loading)되기 전까지는 스플래시만 띄워
    // 어떤 데이터 provider도 실행되지 않게 막는다.
    if (firebaseAvailable) {
      final authState = ref.watch(authStateProvider);
      if (authState.isLoading) {
        return const MaterialApp(
          debugShowCheckedModeBanner: false,
          home: _SplashScreen(),
        );
      }
    }

    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: '한끼를 부탁해',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      routerConfig: router,
    );
  }
}

/// auth 복원 대기 중 표시되는 스플래시
class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🍳', style: TextStyle(fontSize: 64)),
            const SizedBox(height: 16),
            const Text(
              '한끼를 부탁해',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                valueColor:
                    AlwaysStoppedAnimation<Color>(Colors.white.withOpacity(0.9)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
