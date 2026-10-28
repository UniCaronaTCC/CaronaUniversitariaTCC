import 'package:flutter/material.dart';

import '../config/app_colors.dart';

enum EstiloBotaoAcaoHome { padrao, principal, secundario }

// Botao grande reutilizavel nas telas principais.
class BotaoAcaoHome extends StatelessWidget {
  final String texto;
  final IconData icone;
  final EstiloBotaoAcaoHome estilo;

  // Quando for null, o botao fica desativado.
  final VoidCallback? onPressed;

  const BotaoAcaoHome({
    super.key,
    required this.texto,
    required this.icone,
    required this.onPressed,
    this.estilo = EstiloBotaoAcaoHome.padrao,
  });

  @override
  Widget build(BuildContext context) {
    if (estilo != EstiloBotaoAcaoHome.padrao) {
      final principal = estilo == EstiloBotaoAcaoHome.principal;
      final formato = RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      );
      final iconeBotao = Icon(icone, size: 22);
      final rotulo = Text(
        texto,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      );

      return SizedBox(
        width: double.infinity,
        child: principal
            ? ElevatedButton.icon(
                onPressed: onPressed,
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
                  disabledBackgroundColor: AppColors.primary.withValues(
                    alpha: 0.38,
                  ),
                  disabledForegroundColor: Colors.white70,
                  shape: formato,
                  elevation: 0,
                ),
              )
            : OutlinedButton.icon(
                onPressed: onPressed,
                icon: iconeBotao,
                label: rotulo,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  foregroundColor: AppColors.primary,
                  disabledForegroundColor: Colors.black38,
                  side: BorderSide(
                    color: onPressed == null
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
        onPressed: onPressed,
        icon: Icon(icone, size: 32),
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
          elevation: onPressed == null ? 0 : 6,
        ),
      ),
    );
  }
}
