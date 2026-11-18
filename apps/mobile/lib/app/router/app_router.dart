import 'package:alpaso/features/auth/presentation/sign_in_screen.dart';
import 'package:alpaso/features/auth/presentation/sign_up_screen.dart';
import 'package:alpaso/features/business/presentation/business_home_screen.dart';
import 'package:alpaso/features/explore/presentation/explore_screen.dart';
import 'package:alpaso/features/home/presentation/home_shell.dart';
import 'package:alpaso/features/my_bookings/presentation/my_bookings_screen.dart';
import 'package:alpaso/features/profile/presentation/profile_screen.dart';
import 'package:go_router/go_router.dart';

/// Direcciones de la app. Van en español porque el usuario las verá en
/// enlaces compartidos.
abstract final class AppRoutes {
  static const explore = '/explorar';
  static const bookings = '/reservas';
  static const profile = '/perfil';
  static const business = '/negocio';
  static const signIn = '/ingresar';
  static const signUp = '/registro';
}

GoRouter buildRouter({String initialLocation = AppRoutes.explore}) {
  return GoRouter(
    initialLocation: initialLocation,
    routes: [
      // Modo cliente: tres pestañas que conservan su estado al cambiar.
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            HomeShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.explore,
                builder: (context, state) => const ExploreScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.bookings,
                builder: (context, state) => const MyBookingsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.profile,
                builder: (context, state) => const ProfileScreen(),
              ),
            ],
          ),
        ],
      ),
      // Cuenta: se abren encima de las pestañas.
      GoRoute(
        path: AppRoutes.signIn,
        builder: (context, state) => const SignInScreen(),
      ),
      GoRoute(
        path: AppRoutes.signUp,
        builder: (context, state) => const SignUpScreen(),
      ),
      // Modo negocio: tendrá su propia navegación a partir de la etapa 2.
      GoRoute(
        path: AppRoutes.business,
        builder: (context, state) => const BusinessHomeScreen(),
      ),
    ],
  );
}
