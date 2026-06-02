import 'package:flutter/material.dart';
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
import '../screens/profile/favorites_screen.dart';
import '../screens/profile/history_screen.dart';
import '../screens/profile/notifications_screen.dart';
import '../screens/profile/help_screen.dart';
import 'shell_scaffold.dart';

/// go_router를 Riverpod Provider로 감싸서 실제 ProviderScope 컨테이너를 사용
final routerProvider = Provider<GoRouter>((ref) {
  final notifier = _RouterNotifier(ref);
  return GoRouter(
    initialLocation: '/home',
    refreshListenable: notifier,
    redirect: notifier._redirect,
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
            routes: [
              GoRoute(
                path: 'favorites',
                builder: (context, state) => const FavoritesScreen(),
              ),
              GoRoute(
                path: 'history',
                builder: (context, state) => const HistoryScreen(),
              ),
              GoRoute(
                path: 'notifications',
                builder: (context, state) => const NotificationsScreen(),
              ),
              GoRoute(
                path: 'help',
                builder: (context, state) => const HelpScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});

class _RouterNotifier extends ChangeNotifier {
  _RouterNotifier(this._ref) {
    _ref.listen<AsyncValue>(authStateProvider, (_, __) {
      notifyListeners();
    });
  }

  final Ref _ref;

  String? _redirect(BuildContext context, GoRouterState state) {
    final firebaseAvailable = _ref.read(firebaseAvailableProvider);
    if (!firebaseAvailable) return null; // mock 모드: 로그인 불필요

    final authValue = _ref.read(authStateProvider);
    final isLoading = authValue.isLoading;
    final isLoggedIn = authValue.valueOrNull != null;
    final isLoginPage = state.matchedLocation == '/login';

    if (isLoading) return null; // 인증 확인 중엔 대기
    if (!isLoggedIn && !isLoginPage) return '/login';
    if (isLoggedIn && isLoginPage) return '/home';
    return null;
  }
}
