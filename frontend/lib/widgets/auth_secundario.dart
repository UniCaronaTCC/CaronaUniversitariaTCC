import 'package:flutter/material.dart';

import '../config/app_colors.dart';

class TelaAuthSecundaria extends StatelessWidget {
  final String identificador;
  final String titulo;
  final String subtitulo;
  final VoidCallback? onVoltar;
  final Widget? complementoDescricao;
  final Widget child;

  const TelaAuthSecundaria({
    super.key,
    required this.identificador,
    required this.titulo,
    required this.subtitulo,
    required this.onVoltar,
    required this.child,
    this.complementoDescricao,
  });

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.background,
    appBar: AppBar(
      backgroundColor: AppColors.background,
      foregroundColor: AppColors.text,
      elevation: 0,
      scrolledUnderElevation: 0,
      leading: IconButton(
        key: ValueKey('voltar-$identificador'),
        tooltip: 'Voltar para o login',
        onPressed: onVoltar,
        icon: const Icon(Icons.arrow_back_rounded),
      ),
    ),
    body: SafeArea(
      child: SingleChildScrollView(
        key: ValueKey('rolagem-$identificador'),
        padding: const EdgeInsets.all(24),
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: AutofillGroup(
              onDisposeAction: AutofillContextAction.cancel,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Image.asset(
                        'assets/imagens/icone_buscaeu.png',
                        key: ValueKey('logo-$identificador'),
                        width: 96,
                        height: 96,
                        semanticLabel: 'Logo BuscaEu',
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text.rich(
                    const TextSpan(
                      children: [
                        TextSpan(
                          text: 'Busca',
                          style: TextStyle(color: AppColors.text),
                        ),
                        TextSpan(
                          text: 'Eu',
                          style: TextStyle(color: AppColors.primary),
                        ),
                      ],
                    ),
                    key: ValueKey('marca-$identificador'),
                    textAlign: TextAlign.center,
                    semanticsLabel: 'BuscaEu',
                    style: const TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.w700,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 28),
                  Text(
                    titulo,
                    key: ValueKey('titulo-$identificador'),
                    style: const TextStyle(
                      color: AppColors.text,
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    subtitulo,
                    key: ValueKey('descricao-$identificador'),
                    style: const TextStyle(
                      color: Color(0xFF666879),
                      fontSize: 16,
                    ),
                  ),
                  if (complementoDescricao != null) ...[
                    const SizedBox(height: 4),
                    DefaultTextStyle.merge(
                      style: const TextStyle(
                        color: AppColors.text,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                      child: complementoDescricao!,
                    ),
                  ],
                  const SizedBox(height: 24),
                  child,
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
