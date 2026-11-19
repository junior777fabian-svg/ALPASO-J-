import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../admin_repository.dart';
import '../ui.dart';

/// A3. Buscar una reserva por su código y reembolsar.
class BookingsSection extends StatefulWidget {
  const BookingsSection({required this.repository, super.key});

  final AdminRepository repository;

  @override
  State<BookingsSection> createState() => _BookingsSectionState();
}

class _BookingsSectionState extends State<BookingsSection> {
  final _code = TextEditingController();
  Json? _booking;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _find() async {
    try {
      final b = await widget.repository.findBooking(_code.text);
      setState(() => _booking = b);
    } on Object catch (e) {
      setState(() => _booking = null);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(failureText(e))));
    }
  }

  Future<void> _refund(Json b) async {
    final amount = await askText(
      context,
      title: 'Reembolsar ${b['code']}',
      label: 'Monto en soles',
    );
    if (amount == null || !mounted) return;
    final cents = parseSoles(amount);
    if (cents == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Monto no válido.')));
      return;
    }
    final reason = await askText(
      context,
      title: 'Motivo del reembolso',
      label: 'Motivo',
    );
    if (reason == null || !mounted) return;
    if (await runAction(context, () async {
      final done = await widget.repository.refundBooking(
        b['booking_id'] as String,
        cents,
        reason,
      );
      return 'Se reembolsaron ${soles(done)}.';
    })) {
      await _find();
    }
  }

  @override
  Widget build(BuildContext context) {
    final b = _booking;
    final date = DateFormat('d MMM yyyy HH:mm');
    return ListView(
      children: [
        TextField(
          key: const Key('booking-query'),
          controller: _code,
          textCapitalization: TextCapitalization.characters,
          decoration: InputDecoration(
            labelText: 'Código de la reserva',
            suffixIcon: IconButton(
              tooltip: 'Buscar reserva',
              icon: const Icon(Icons.search),
              onPressed: _find,
            ),
          ),
          onSubmitted: (_) => _find(),
        ),
        if (b != null)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${b['code']} · ${b['status']}',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  Text(
                    '${b['lodging_name']} · ${date.format(DateTime.parse(b['arrival_at'] as String).toLocal())}',
                  ),
                  Text(
                    'Cliente: ${b['customer_name']} · ${b['customer_email']}',
                  ),
                  Text(
                    'Total ${soles(b['total_cents'] as num)} · reembolsado ${soles(b['refunded_cents'] as num)}'
                    '${b['paid_out'] == true ? ' · ya liquidada' : ''}',
                  ),
                  const SizedBox(height: 8),
                  for (final e in (b['events'] as List).cast<Json>())
                    Text(
                      '· ${e['to']} ${e['note']}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: () => _refund(b),
                    child: const Text('Reembolsar'),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
