import 'package:flutter/widgets.dart';

/// Cria os campos de texto de uma janela e só os descarta quando ela sai da
/// tela, depois da animação de fechar. Descartar logo após o
/// `await showDialog` quebra a tela, porque a janela ainda está fechando e
/// continua usando os campos.
class DialogTextControllers extends StatefulWidget {
  const DialogTextControllers({
    super.key,
    required this.initialTexts,
    required this.builder,
  });

  /// Um campo para cada texto inicial, na mesma ordem.
  final List<String> initialTexts;
  final Widget Function(
    BuildContext context,
    List<TextEditingController> controllers,
  )
  builder;

  @override
  State<DialogTextControllers> createState() => _DialogTextControllersState();
}

class _DialogTextControllersState extends State<DialogTextControllers> {
  late final List<TextEditingController> _controllers = [
    for (final text in widget.initialTexts) TextEditingController(text: text),
  ];

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _controllers);
}
