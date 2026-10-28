import 'package:flutter/material.dart';

import '../config/app_colors.dart';

enum EstiloBotaoAcaoHome { padrao, principal, secundario }

// Botao grande reutilizavel nas telas principais.
class BotaoAcaoHome extends StatelessWidget {
  final String texto;
  final IconData icone;
  final EstiloBotaoAcaoHome estilo;
  final bool carregando;

  // Quando for null, o botao fica desativado.
  final VoidCallback? onPressed;

  const BotaoAcaoHome({
    super.key,
    required this.texto,
    required this.icone,
    required this.onPressed,
    this.estilo = EstiloBotaoAcaoHome.padrao,
    this.carregando = false,
  });

  @override
  Widget build(BuildContext context) {
    final aoPressionar = carregando ? null : onPressed;
    Widget construirIcone(double tamanho, Color cor) => carregando
        ? SizedBox(
            width: tamanho,
            height: tamanho,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: cor,
              semanticsLabel: 'Preparando abertura',
            ),
          )
        : Icon(icone, size: tamanho);
    if (estilo != EstiloBotaoAcaoHome.padrao) {
      final principal = estilo == EstiloBotaoAcaoHome.principal;
      final formato = RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      );
      final iconeBotao = construirIcone(
        22,
        principal ? Colors.white : AppColors.primary,
      );
      final rotulo = Text(
        texto,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      );

      return SizedBox(
        width: double.infinity,
        child: principal
            ? ElevatedButton.icon(
                onPressed: aoPressionar,
                icon: iconeBotao,
                label: rotulo,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(54),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: carregando
                      ? AppColors.primary
                      : AppColors.primary.withValues(alpha: 0.38),
                  disabledForegroundColor: carregando
                      ? Colors.white
                      : Colors.white70,
                  shape: formato,
                  elevation: 0,
                ),
              )
            : OutlinedButton.icon(
                onPressed: aoPressionar,
                icon: iconeBotao,
                label: rotulo,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  foregroundColor: AppColors.primary,
                  disabledForegroundColor: carregando
                      ? AppColors.primary
                      : Colors.black38,
                  side: BorderSide(
                    color: aoPressionar == null && !carregando
                        ? Colors.black26
                        : AppColors.primary,
                  ),
                  shape: formato,
                ),
              ),
      );
    }

    return SizedBox(
      width: double.infinity,
      height: 82,
      child: ElevatedButton.icon(
        onPressed: aoPressionar,
        icon: construirIcone(32, Colors.white),
        label: Text(
          texto,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.55),
          disabledForegroundColor: Colors.white70,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          elevation: aoPressionar == null ? 0 : 6,
        ),
      ),
    );
  }
}
