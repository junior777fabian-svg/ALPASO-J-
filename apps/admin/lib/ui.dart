import 'package:material_ui/material_ui.dart';

import 'admin_repository.dart';

/// "S/ 45.00".
String soles(num cents) {
  final c = cents.round();
  final whole = (c.abs() ~/ 100).toString().replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (_) => ',',
  );
  return '${c < 0 ? '-' : ''}S/ $whole.${(c.abs() % 100).toString().padLeft(2, '0')}';
}

/// Lee soles escritos ("45", "45.5", "45,50") y devuelve céntimos.
int? parseSoles(String text) {
  final m = RegExp(r'^(\d{1,6})(?:[.,](\d{1,2}))?$').firstMatch(text.trim());
  if (m == null) return null;
  return int.parse(m.group(1)!) * 100 +
      int.parse((m.group(2) ?? '').padRight(2, '0'));
}

/// Mensaje para el administrador según el código del servidor.
String failureText(Object error) {
  final code = error is AdminFailure ? error.code : '';
  return switch (code) {
    'not_admin' => 'Esta cuenta no es administradora.',
    'invalid_credentials' => 'Correo o contraseña incorrectos.',
    'reason_required' || 'review_note_required' => 'Escribe el motivo.',
    'reference_required' => 'Escribe la referencia de la transferencia.',
    'invalid_status' =>
      'Ya no está en un estado que permita esa acción. Actualiza.',
    'lodging_incomplete' => 'Al hostal le falta información para publicarse.',
    'nothing_to_pay' => 'No hay ventas por liquidar.',
    'nothing_to_refund' => 'Ya no queda nada por reembolsar.',
    'already_paid_out' =>
      'Esa reserva ya se liquidó al hostal: resuélvelo fuera del panel.',
    'cannot_block_admin' => 'No se puede bloquear a un administrador.',
    'booking_not_found' => 'No hay una reserva con ese código.',
    'query_too_short' => 'Escribe al menos 3 letras.',
    'network' => 'No hay conexión con el servidor.',
    _ => 'Algo salió mal ($code).',
  };
}

/// Pide un texto (motivo, referencia…). Nulo si se cancela.
Future<String?> askText(
  BuildContext context, {
  required String title,
  required String label,
  String confirm = 'Confirmar',
  Key? fieldKey,
}) {
  return showDialog<String>(
    context: context,
    builder: (_) => _AskTextDialog(
      title: title,
      label: label,
      confirm: confirm,
      fieldKey: fieldKey,
    ),
  );
}

class _AskTextDialog extends StatefulWidget {
  const _AskTextDialog({
    required this.title,
    required this.label,
    required this.confirm,
    this.fieldKey,
  });

  final String title;
  final String label;
  final String confirm;
  final Key? fieldKey;

  @override
  State<_AskTextDialog> createState() => _AskTextDialogState();
}

class _AskTextDialogState extends State<_AskTextDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        key: widget.fieldKey,
        controller: _controller,
        autofocus: true,
        maxLines: 3,
        decoration: InputDecoration(labelText: widget.label),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          key: const Key('ask-confirm'),
          onPressed: () => Navigator.of(context).pop(_controller.text),
          child: Text(widget.confirm),
        ),
      ],
    );
  }
}

/// Ejecuta una acción, muestra el resultado o el error, y avisa para recargar.
Future<bool> runAction(
  BuildContext context,
  Future<String> Function() action,
) async {
  final messenger = ScaffoldMessenger.of(context);
  try {
    final message = await action();
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
    return true;
  } on Object catch (error) {
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(failureText(error))));
    return false;
  }
}

/// Carga una lista con FutureBuilder y un botón para actualizar.
class Loader<T> extends StatefulWidget {
  const Loader({required this.load, required this.builder, super.key});

  final Future<T> Function() load;
  final Widget Function(BuildContext context, T data, VoidCallback reload)
  builder;

  @override
  State<Loader<T>> createState() => _LoaderState<T>();
}

class _LoaderState<T> extends State<Loader<T>> {
  late Future<T> _future = widget.load();

  void _reload() {
    final next = widget.load();
    setState(() {
      _future = next;
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<T>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(failureText(snapshot.error!)),
                TextButton(onPressed: _reload, child: const Text('Reintentar')),
              ],
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        return widget.builder(context, snapshot.data as T, _reload);
      },
    );
  }
}
