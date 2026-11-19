import 'package:material_ui/material_ui.dart';

import '../admin_repository.dart';
import '../ui.dart';

/// A5. Incidencias de soporte y Libro de Reclamaciones.
class SupportSection extends StatelessWidget {
  const SupportSection({required this.repository, super.key});

  final AdminRepository repository;

  @override
  Widget build(BuildContext context) {
    return Loader<(List<Json>, List<Json>)>(
      load: () async =>
          (await repository.supportCases(), await repository.complaints()),
      builder: (context, data, reload) => ListView(
        children: [
          Text(
            'Incidencias abiertas',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          if (data.$1.isEmpty) const Text('Ninguna.'),
          for (final c in data.$1)
            ListTile(
              title: Text(c['subject'] as String),
              subtitle: Text(c['message'] as String),
              trailing: OutlinedButton(
                onPressed: () async {
                  final text = await askText(
                    context,
                    title: 'Resolver',
                    label: 'Qué se hizo',
                  );
                  if (text == null || !context.mounted) return;
                  if (await runAction(context, () async {
                    await repository.resolveSupportCase(
                      c['id'] as String,
                      text,
                    );
                    return 'Incidencia resuelta.';
                  })) {
                    reload();
                  }
                },
                child: const Text('Resolver'),
              ),
            ),
          const Divider(),
          Text(
            'Libro de Reclamaciones: por responder',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          if (data.$2.isEmpty) const Text('Ninguno.'),
          for (final c in data.$2)
            ListTile(
              title: Text(
                '${c['number']} · ${c['kind']} · ${c['consumer_name']}',
              ),
              subtitle: Text(
                '${c['detail']}\nPide: ${c['consumer_request']}\n${c['consumer_email']}',
              ),
              isThreeLine: true,
              trailing: OutlinedButton(
                onPressed: () async {
                  final text = await askText(
                    context,
                    title: 'Responder ${c['number']}',
                    label: 'Respuesta (se envía al consumidor)',
                  );
                  if (text == null || !context.mounted) return;
                  if (await runAction(context, () async {
                    await repository.answerComplaint(
                      c['number'] as String,
                      text,
                    );
                    return 'Respuesta registrada.';
                  })) {
                    reload();
                  }
                },
                child: const Text('Responder'),
              ),
            ),
        ],
      ),
    );
  }
}
