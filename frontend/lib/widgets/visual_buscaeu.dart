import 'package:flutter/material.dart';

import '../config/app_colors.dart';

class VisualBuscaEu extends StatelessWidget {
  final Widget child;
  const VisualBuscaEu({super.key, required this.child});

  static const texto = Color(0xFF151824);
  static const secundario = Color(0xFF646B7B);
  static const borda = Color(0xFFE2E2E8);
  static const suave = Color(0xFFF6F6F9);
  static const titulo = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w700,
    color: texto,
  );
  static const descricao = TextStyle(
    fontSize: 14,
    color: secundario,
    height: 1.4,
  );

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context);
    final forma = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(8),
    );
    return Theme(
      data: base.copyWith(
        appBarTheme: base.appBarTheme.copyWith(
          backgroundColor: Colors.white,
          foregroundColor: texto,
          elevation: 0,
          scrolledUnderElevation: 0,
          titleTextStyle: base.textTheme.titleLarge?.copyWith(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: texto,
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            disabledBackgroundColor: suave,
            disabledForegroundColor: secundario,
            elevation: 0,
            minimumSize: const Size(48, 48),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            shape: forma,
            textStyle: base.textTheme.labelLarge?.copyWith(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            minimumSize: const Size(48, 48),
            shape: forma,
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.primary,
            side: const BorderSide(color: AppColors.primary),
            minimumSize: const Size(48, 48),
            shape: forma,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            textStyle: base.textTheme.labelLarge?.copyWith(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        dividerTheme: const DividerThemeData(color: borda, thickness: 1),
        listTileTheme: base.listTileTheme.copyWith(
          iconColor: secundario,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 4,
          ),
          titleTextStyle: base.textTheme.bodyLarge?.copyWith(
            color: texto,
            fontWeight: FontWeight.w600,
          ),
          subtitleTextStyle: base.textTheme.bodySmall?.copyWith(
            color: secundario,
            height: 1.4,
          ),
          minVerticalPadding: 12,
        ),
        tabBarTheme: base.tabBarTheme.copyWith(
          labelColor: AppColors.primary,
          unselectedLabelColor: secundario,
          indicatorColor: AppColors.primary,
          dividerColor: borda,
          labelStyle: base.textTheme.labelLarge?.copyWith(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      child: child,
    );
  }
}

class CartaoBuscaEu extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color cor;
  final Key? chaveCartao;
  const CartaoBuscaEu({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.cor = Colors.white,
    this.chaveCartao,
  });

  @override
  Widget build(BuildContext context) => Container(
    key: chaveCartao,
    width: double.infinity,
    padding: padding,
    decoration: BoxDecoration(
      color: cor,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: VisualBuscaEu.borda),
    ),
    child: child,
  );
}

class SeloBuscaEu extends StatelessWidget {
  final String texto;
  final Color cor;
  const SeloBuscaEu({
    super.key,
    required this.texto,
    this.cor = AppColors.primary,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: cor.withValues(alpha: .1),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(
      texto,
      style: TextStyle(color: cor, fontSize: 12, fontWeight: FontWeight.w600),
    ),
  );
}

class CamposLadoALado extends StatelessWidget {
  final Widget primeiro;
  final Widget segundo;
  final double larguraMinima;
  const CamposLadoALado({
    super.key,
    required this.primeiro,
    required this.segundo,
    this.larguraMinima = 320,
  });

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      if (constraints.maxWidth < larguraMinima ||
          MediaQuery.textScalerOf(context).scale(16) > 20) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [primeiro, const SizedBox(height: 16), segundo],
        );
      }
      return Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(child: primeiro),
          const SizedBox(width: 12),
          Expanded(child: segundo),
        ],
      );
    },
  );
}
