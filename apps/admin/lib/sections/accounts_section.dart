import 'package:material_ui/material_ui.dart';

import '../admin_repository.dart';
import '../ui.dart';

/// A2. Buscar cuentas, bloquear y desbloquear.
class AccountsSection extends StatefulWidget {
  const AccountsSection({required this.repository, super.key});

  final AdminRepository repository;

  @override
  State<AccountsSection> createState() => _AccountsSectionState();
}

class _AccountsSectionState extends State<AccountsSection> {
  final _query = TextEditingController();
  List<Json> _results = const [];

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    try {
      final r = await widget.repository.findUsers(_query.text);
      setState(() => _results = r);
    } on Object catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(failureText(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextField(
          key: const Key('users-query'),
          controller: _query,
          decoration: InputDecoration(
            labelText: 'Correo o nombre',
            suffixIcon: IconButton(
              tooltip: 'Buscar',
              icon: const Icon(Icons.search),
              onPressed: _search,
            ),
          ),
          onSubmitted: (_) => _search(),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: ListView(
            children: [
              for (final u in _results)
                ListTile(
                  title: Text('${u['email']}'),
                  subtitle: Text(
                    [
                      (u['full_name'] as String?)?.isNotEmpty == true
                          ? u['full_name']
                          : 'Sin nombre',
                      if (u['is_admin'] == true) 'administrador',
                      if (u['is_blocked'] == true) 'BLOQUEADA',
                    ].join(' · '),
                  ),
                  trailing: u['is_admin'] == true
                      ? null
                      : OutlinedButton(
                          onPressed: () async {
                            final block = u['is_blocked'] != true;
                            final reason = await askText(
                              context,
                              title: block
                                  ? 'Bloquear ${u['email']}'
                                  : 'Desbloquear ${u['email']}',
                              label: 'Motivo',
                            );
                            if (reason == null || !context.mounted) return;
                            if (await runAction(context, () async {
                              await widget.repository.setBlocked(
                                u['user_id'] as String,
                                blocked: block,
                                reason: reason,
                              );
                              return block
                                  ? 'Cuenta bloqueada.'
                                  : 'Cuenta desbloqueada.';
                            })) {
                              await _search();
                            }
                          },
                          child: Text(
                            u['is_blocked'] == true
                                ? 'Desbloquear'
                                : 'Bloquear',
                          ),
                        ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
