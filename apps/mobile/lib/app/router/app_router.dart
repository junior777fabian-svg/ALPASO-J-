import 'package:alpaso/features/auth/presentation/sign_in_screen.dart';
import 'package:alpaso/features/auth/presentation/sign_up_screen.dart';
import 'package:alpaso/features/business/presentation/business_home_screen.dart';
import 'package:alpaso/features/business/presentation/lodging_detail_screen.dart';
import 'package:alpaso/features/business/presentation/lodging_form_screen.dart';
import 'package:alpaso/features/business/presentation/product_form_screen.dart';
import 'package:alpaso/features/business/presentation/room_type_form_screen.dart';
import 'package:alpaso/features/explore/presentation/explore_screen.dart';
import 'package:alpaso/features/home/presentation/home_shell.dart';
import 'package:alpaso/features/lodging/presentation/public_lodging_screen.dart';
import 'package:alpaso/features/lodging/presentation/public_room_type_screen.dart';
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
  static String publicLodging(String id) => '/hostal/$id';
  static String publicRoomType(String id, String typeId) =>
      '/hostal/$id/cuarto/$typeId';
  static const newLodging = '/negocio/hostal/nuevo';
  static String lodging(String id) => '/negocio/hostal/$id';
  static String editLodging(String id) => '/negocio/hostal/$id/editar';
  static String newRoomType(String id) => '/negocio/hostal/$id/cuarto/nuevo';
  static String editRoomType(String id, String typeId) =>
      '/negocio/hostal/$id/cuarto/$typeId';
  static String newProduct(String id) => '/negocio/hostal/$id/extra/nuevo';
  static String editProduct(String id, String productId) =>
      '/negocio/hostal/$id/extra/$productId';
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
      // Ficha pública de un hostal y de sus cuartos (C3 y C4).
      GoRoute(
        path: '/hostal/:id',
        builder: (context, state) =>
            PublicLodgingScreen(lodgingId: state.pathParameters['id']!),
        routes: [
          GoRoute(
            path: 'cuarto/:typeId',
            builder: (context, state) => PublicRoomTypeScreen(
              lodgingId: state.pathParameters['id']!,
              roomTypeId: state.pathParameters['typeId']!,
            ),
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
        routes: [
          GoRoute(
            path: 'hostal/nuevo',
            builder: (context, state) => const LodgingFormScreen(),
          ),
          GoRoute(
            path: 'hostal/:id',
            builder: (context, state) =>
                LodgingDetailScreen(lodgingId: state.pathParameters['id']!),
            routes: [
              GoRoute(
                path: 'editar',
                builder: (context, state) =>
                    LodgingFormScreen(lodgingId: state.pathParameters['id']),
              ),
              GoRoute(
                path: 'cuarto/nuevo',
                builder: (context, state) =>
                    RoomTypeFormScreen(lodgingId: state.pathParameters['id']!),
              ),
              GoRoute(
                path: 'cuarto/:typeId',
                builder: (context, state) => RoomTypeFormScreen(
                  lodgingId: state.pathParameters['id']!,
                  roomTypeId: state.pathParameters['typeId'],
                ),
              ),
              GoRoute(
                path: 'extra/nuevo',
                builder: (context, state) =>
                    ProductFormScreen(lodgingId: state.pathParameters['id']!),
              ),
              GoRoute(
                path: 'extra/:productId',
                builder: (context, state) => ProductFormScreen(
                  lodgingId: state.pathParameters['id']!,
                  productId: state.pathParameters['productId'],
                ),
              ),
            ],
          ),
        ],
      ),
    ],
  );
}
