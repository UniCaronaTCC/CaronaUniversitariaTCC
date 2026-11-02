import 'package:flutter/material.dart';

enum TipoAviso { informacao, sucesso, atencao, erro }

class AvisoApp extends StatelessWidget {
  final String mensagem;
  final TipoAviso tipo;

  const AvisoApp({
    super.key,
    required this.mensagem,
    this.tipo = TipoAviso.informacao,
  });

  static ScaffoldFeatureController<SnackBar, SnackBarClosedReason>? mostrar(
    BuildContext context,
    String mensagem, {
    TipoAviso tipo = TipoAviso.informacao,
    SnackBarAction? acao,
    Duration duracao = const Duration(seconds: 4),
  }) {
    if (!context.mounted) return null;
    return ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: AvisoApp(mensagem: mensagem, tipo: tipo),
        action: acao,
        duration: duracao,
      ),
    );
  }

  // Mantem a apresentacao atual; o tipo fica disponivel para o futuro visual.
  @override
  Widget build(BuildContext context) => Text(mensagem);
}
