import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';
import '../screens/auth/login_screen.dart';
import '../screens/home/home_screen.dart';
import '../screens/fridge/fridge_screen.dart';
import '../screens/recipe/recipe_list_screen.dart';
import '../screens/recipe/recipe_detail_screen.dart';
import '../screens/learn/learn_screen.dart';
import '../screens/profile/profile_screen.dart';
import 'shell_scaffold.dart';

// go_router에서 Riverpod provider를 읽기 위한 컨테이너
final _routerRef = ProviderContainer();

final appRouter = GoRouter(
  initialLocation: '/home',
  redirect: (context, state) {
    final firebaseAvailable = _routerRef.read(firebaseAvailableProvider);
    if (!firebaseAvailable) return null; // 목 모드: 로그인 불필요

    final authValue = _routerRef.read(authStateProvider);
    final isLoggedIn = authValue.valueOrNull != null;
    final isLoginPage = state.matchedLocation == '/login';

    if (!isLoggedIn && !isLoginPage) return '/login';
    if (isLoggedIn && isLoginPage) return '/home';
    return null;
  },
  refreshListenable: _RouterRefreshStream(_routerRef),
  routes: [
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginScreen(),
    ),
    ShellRoute(
      builder: (context, state, child) => ShellScaffold(child: child),
      routes: [
        GoRoute(
          path: '/home',
          builder: (context, state) => const HomeScreen(),
        ),
        GoRoute(
          path: '/fridge',
          builder: (context, state) => const FridgeScreen(),
        ),
        GoRoute(
          path: '/recipe',
          builder: (context, state) => const RecipeListScreen(),
          routes: [
            GoRoute(
              path: 'detail',
              builder: (context, state) => const RecipeDetailScreen(),
            ),
          ],
        ),
        GoRoute(
          path: '/learn',
          builder: (context, state) => const LearnScreen(),
        ),
        GoRoute(
          path: '/profile',
          builder: (context, state) => const ProfileScreen(),
        ),
      ],
    ),
  ],
);

/// authStateProvider 변화 시 go_router를 갱신하는 Listenable
class _RouterRefreshStream extends ChangeNotifier {
  _RouterRefreshStream(ProviderContainer container) {
    container.listen<AsyncValue>(authStateProvider, (_, __) {
      notifyListeners();
    });
  }
}
