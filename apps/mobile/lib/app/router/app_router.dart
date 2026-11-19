import 'package:alpaso/features/auth/presentation/sign_in_screen.dart';
import 'package:alpaso/features/auth/presentation/sign_up_screen.dart';
import 'package:alpaso/features/business/presentation/business_home_screen.dart';
import 'package:alpaso/features/business/presentation/earnings_screen.dart';
import 'package:alpaso/features/business/presentation/lodging_detail_screen.dart';
import 'package:alpaso/features/business/presentation/lodging_form_screen.dart';
import 'package:alpaso/features/business/presentation/product_form_screen.dart';
import 'package:alpaso/features/business/presentation/reception_screen.dart';
import 'package:alpaso/features/business/presentation/staff_screen.dart';
import 'package:alpaso/features/business/presentation/room_type_form_screen.dart';
import 'package:alpaso/features/explore/presentation/explore_screen.dart';
import 'package:alpaso/features/home/presentation/home_shell.dart';
import 'package:alpaso/features/lodging/presentation/public_lodging_screen.dart';
import 'package:alpaso/features/profile/presentation/account_actions.dart';
import 'package:alpaso/features/lodging/presentation/public_room_type_screen.dart';
import 'package:alpaso/features/booking/presentation/booking_screen.dart';
import 'package:alpaso/features/booking/presentation/demo_checkout_screen.dart';
import 'package:alpaso/features/my_bookings/presentation/booking_detail_screen.dart';
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
  static const support = '/ayuda';
  static const deleteAccount = '/eliminar-cuenta';
  static String publicLodging(String id) => '/hostal/$id';
  static String book(String lodgingId, String typeId) =>
      '/reservar/$lodgingId/$typeId';
  static String payment(String bookingId) => '/pago/$bookingId';
  static String bookingDetail(String bookingId) => '/reservas/$bookingId';
  static String publicRoomType(String id, String typeId) =>
      '/hostal/$id/cuarto/$typeId';
  static const newLodging = '/negocio/hostal/nuevo';
  static String lodging(String id) => '/negocio/hostal/$id';
  static String editLodging(String id) => '/negocio/hostal/$id/editar';
  static String reception(String id) => '/negocio/hostal/$id/hoy';
  static String staff(String id) => '/negocio/hostal/$id/personal';
  static String earnings(String id) => '/negocio/hostal/$id/ingresos';
  static String hostBookings(String id) => '/negocio/hostal/$id/reservas';
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
                routes: [
                  GoRoute(
                    path: ':id',
                    builder: (context, state) => BookingDetailScreen(
                      bookingId: state.pathParameters['id']!,
                    ),
                  ),
                ],
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
      // Reservar y pagar (C5).
      GoRoute(
        path: '/reservar/:lodgingId/:typeId',
        builder: (context, state) => BookingScreen(
          lodgingId: state.pathParameters['lodgingId']!,
          roomTypeId: state.pathParameters['typeId']!,
        ),
      ),
      GoRoute(
        path: '/pago/:id',
        builder: (context, state) =>
            PaymentScreen(bookingId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: AppRoutes.support,
        builder: (context, state) => const SupportScreen(),
      ),
      GoRoute(
        path: AppRoutes.deleteAccount,
        builder: (context, state) => const DeleteAccountScreen(),
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
                path: 'hoy',
                builder: (context, state) =>
                    ReceptionScreen(lodgingId: state.pathParameters['id']!),
              ),
              GoRoute(
                path: 'ingresos',
                builder: (context, state) =>
                    EarningsScreen(lodgingId: state.pathParameters['id']!),
              ),
              GoRoute(
                path: 'personal',
                builder: (context, state) =>
                    StaffScreen(lodgingId: state.pathParameters['id']!),
              ),
              GoRoute(
                path: 'reservas',
                builder: (context, state) =>
                    HostBookingsScreen(lodgingId: state.pathParameters['id']!),
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
