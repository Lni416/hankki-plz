import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app/router.dart';
import 'core/theme/app_theme.dart';

void main() {
  runApp(const ProviderScope(child: HankkiApp()));
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
