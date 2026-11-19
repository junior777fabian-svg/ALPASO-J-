import 'package:material_ui/material_ui.dart';

import '../admin_repository.dart';
import '../ui.dart';

/// A4. Liquidaciones a hostales.
class MoneySection extends StatelessWidget {
  const MoneySection({required this.repository, super.key});

  final AdminRepository repository;

  @override
  Widget build(BuildContext context) {
    return Loader<(List<Json>, List<Json>)>(
      load: () async =>
          (await repository.pendingPayouts(), await repository.payouts()),
      builder: (context, data, reload) => ListView(
        children: [
          Text('Por liquidar', style: Theme.of(context).textTheme.titleMedium),
          if (data.$1.isEmpty) const Text('Nada pendiente.'),
          for (final p in data.$1)
            ListTile(
              title: Text(p['lodging_name'] as String),
              subtitle: Text(
                '${p['bookings_count']} reservas · ventas ${soles(p['gross_cents'] as num)}'
                '${p['has_payout_account'] == true ? '' : ' · SIN CUENTA DE DESTINO'}',
              ),
              trailing: FilledButton(
                onPressed: () async {
                  if (await runAction(context, () async {
                    final r = await repository.createPayout(
                      p['lodging_id'] as String,
                    );
                    return 'Liquidación creada: ${soles(r['net_cents'] as num)} para el hostal.';
                  })) {
                    reload();
                  }
                },
                child: const Text('Liquidar'),
              ),
            ),
          const Divider(),
          Text('Liquidaciones', style: Theme.of(context).textTheme.titleMedium),
          for (final p in data.$2)
            ListTile(
              title: Text(
                '${(p['lodgings'] as Map?)?['name'] ?? ''} · ${soles(p['net_cents'] as num)}',
              ),
              subtitle: Text(
                'Ventas ${soles(p['gross_cents'] as num)} − comisión ${soles(p['commission_cents'] as num)}'
                ' · ${p['bookings_count']} reservas'
                '${p['status'] == 'paid' ? ' · pagada (${p['transfer_reference']})' : ''}',
              ),
              trailing: p['status'] == 'paid'
                  ? null
                  : OutlinedButton(
                      onPressed: () async {
                        final ref = await askText(
                          context,
                          title: 'Registrar transferencia',
                          label: 'Número de operación',
                        );
                        if (ref == null || !context.mounted) return;
                        if (await runAction(context, () async {
                          await repository.markPayoutPaid(
                            p['id'] as String,
                            ref,
                          );
                          return 'Transferencia registrada.';
                        })) {
                          reload();
                        }
                      },
                      child: const Text('Marcar pagada'),
                    ),
            ),
        ],
      ),
    );
  }
}
