import 'package:material_ui/material_ui.dart';

/// Pide un texto en un diálogo. Devuelve el texto o nulo si se canceló.
///
/// El diálogo es dueño de su campo: así el campo vive hasta que termina la
/// animación de cierre.
Future<String?> showTextPrompt(
  BuildContext context, {
  required String title,
  required String label,
  required String confirmLabel,
  required String cancelLabel,
  Key? fieldKey,
  Key? confirmKey,
  int maxLength = 300,
  bool uppercase = false,
}) {
  return showDialog<String>(
    context: context,
    builder: (context) => _TextPromptDialog(
      title: title,
      label: label,
      confirmLabel: confirmLabel,
      cancelLabel: cancelLabel,
      fieldKey: fieldKey,
      confirmKey: confirmKey,
      maxLength: maxLength,
      uppercase: uppercase,
    ),
  );
}

class _TextPromptDialog extends StatefulWidget {
  const _TextPromptDialog({
    required this.title,
    required this.label,
    required this.confirmLabel,
    required this.cancelLabel,
    required this.maxLength,
    required this.uppercase,
    this.fieldKey,
    this.confirmKey,
  });

  final String title;
  final String label;
  final String confirmLabel;
  final String cancelLabel;
  final int maxLength;
  final bool uppercase;
  final Key? fieldKey;
  final Key? confirmKey;

  @override
  State<_TextPromptDialog> createState() => _TextPromptDialogState();
}

class _TextPromptDialogState extends State<_TextPromptDialog> {
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
        maxLength: widget.maxLength,
        textCapitalization: widget.uppercase
            ? TextCapitalization.characters
            : TextCapitalization.sentences,
        decoration: InputDecoration(labelText: widget.label),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(widget.cancelLabel),
        ),
        FilledButton(
          key: widget.confirmKey,
          onPressed: () => Navigator.of(context).pop(_controller.text),
          child: Text(widget.confirmLabel),
        ),
      ],
    );
  }
}
