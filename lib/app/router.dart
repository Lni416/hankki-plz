import 'package:go_router/go_router.dart';
import '../screens/home/home_screen.dart';
import '../screens/fridge/fridge_screen.dart';
import '../screens/recipe/recipe_list_screen.dart';
import '../screens/recipe/recipe_detail_screen.dart';
import '../screens/learn/learn_screen.dart';
import '../screens/profile/profile_screen.dart';
import 'shell_scaffold.dart';

final appRouter = GoRouter(
  initialLocation: '/home',
  routes: [
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
