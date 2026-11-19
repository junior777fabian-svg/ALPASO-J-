import 'package:material_ui/material_ui.dart';

import '../admin_repository.dart';
import '../ui.dart';

/// A1. Hostales por revisar, publicados y suspendidos.
class LodgingsSection extends StatefulWidget {
  const LodgingsSection({required this.repository, super.key});

  final AdminRepository repository;

  @override
  State<LodgingsSection> createState() => _LodgingsSectionState();
}

class _LodgingsSectionState extends State<LodgingsSection> {
  String _status = 'pending_review';

  @override
  Widget build(BuildContext context) {
    final repo = widget.repository;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'pending_review', label: Text('Por revisar')),
            ButtonSegment(value: 'published', label: Text('Publicados')),
            ButtonSegment(value: 'suspended', label: Text('Suspendidos')),
          ],
          selected: {_status},
          onSelectionChanged: (s) => setState(() => _status = s.first),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: Loader<List<Json>>(
            key: ValueKey(_status),
            load: () => repo.lodgings(_status),
            builder: (context, list, reload) => list.isEmpty
                ? const Center(child: Text('No hay hostales aquí.'))
                : ListView(
                    children: [
                      for (final l in list)
                        Card(
                          child: ListTile(
                            key: Key('lodging-${l['id']}'),
                            title: Text(l['name'] as String),
                            subtitle: Text(
                              '${l['address']} · ${(l['districts'] as Map?)?['name'] ?? ''}',
                            ),
                            trailing: Wrap(
                              spacing: 8,
                              children: switch (_status) {
                                'pending_review' => [
                                  FilledButton(
                                    onPressed: () async {
                                      if (await runAction(context, () async {
                                        await repo.reviewLodging(
                                          l['id'] as String,
                                          approve: true,
                                        );
                                        return 'Hostal publicado.';
                                      })) {
                                        reload();
                                      }
                                    },
                                    child: const Text('Aprobar'),
                                  ),
                                  OutlinedButton(
                                    onPressed: () async {
                                      final note = await askText(
                                        context,
                                        title: 'Rechazar ${l['name']}',
                                        label: 'Motivo (lo verá el dueño)',
                                      );
                                      if (note == null || !context.mounted) {
                                        return;
                                      }
                                      if (await runAction(context, () async {
                                        await repo.reviewLodging(
                                          l['id'] as String,
                                          approve: false,
                                          note: note,
                                        );
                                        return 'Hostal rechazado.';
                                      })) {
                                        reload();
                                      }
                                    },
                                    child: const Text('Rechazar'),
                                  ),
                                ],
                                _ => [
                                  OutlinedButton(
                                    onPressed: () async {
                                      final suspend = _status == 'published';
                                      final reason = await askText(
                                        context,
                                        title: suspend
                                            ? 'Suspender ${l['name']}'
                                            : 'Reponer ${l['name']}',
                                        label: 'Motivo',
                                      );
                                      if (reason == null || !context.mounted) {
                                        return;
                                      }
                                      if (await runAction(context, () async {
                                        await repo.setLodgingSuspended(
                                          l['id'] as String,
                                          suspended: suspend,
                                          reason: reason,
                                        );
                                        return suspend
                                            ? 'Hostal suspendido.'
                                            : 'Hostal publicado otra vez.';
                                      })) {
                                        reload();
                                      }
                                    },
                                    child: Text(
                                      _status == 'published'
                                          ? 'Suspender'
                                          : 'Reponer',
                                    ),
                                  ),
                                ],
                              },
                            ),
                          ),
                        ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }
}
