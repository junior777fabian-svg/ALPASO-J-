import 'package:alpaso/features/auth/data/auth_providers.dart';
import 'package:alpaso/features/booking/data/booking_repository.dart';
import 'package:alpaso/features/booking/domain/booking.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final bookingRepositoryProvider = Provider<BookingRepository?>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return client == null ? null : SupabaseBookingRepository(client);
});

final menuProvider = FutureProvider.family<List<MenuItem>, String>((
  ref,
  lodgingId,
) {
  return ref.watch(bookingRepositoryProvider)!.menu(lodgingId);
});

/// Reservas de la cuenta en sesión. Vacío sin sesión o sin servidor.
final myBookingsProvider = FutureProvider<List<Booking>>((ref) async {
  final user = await ref.watch(authUserProvider.future);
  final repository = ref.watch(bookingRepositoryProvider);
  if (user == null || repository == null) return const [];
  return repository.myBookings();
});

final bookingProvider = FutureProvider.family<Booking, String>((ref, id) {
  return ref.watch(bookingRepositoryProvider)!.booking(id);
});
