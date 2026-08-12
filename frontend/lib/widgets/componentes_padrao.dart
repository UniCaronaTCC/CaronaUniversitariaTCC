import 'package:flutter/material.dart';

import '../config/app_colors.dart';

class CampoTextoPadrao extends StatelessWidget {
  final String label;
  final TextEditingController? controller;
  final bool obscureText;
  final TextInputType? keyboardType;
  final String? valorInicial;
  final ValueChanged<String>? onChanged;

  const CampoTextoPadrao({
    super.key,
    required this.label,
    this.controller,
    this.obscureText = false,
    this.keyboardType,
    this.valorInicial,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      initialValue: controller == null ? valorInicial : null,
      obscureText: obscureText,
      keyboardType: keyboardType,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        enabledBorder: const OutlineInputBorder(
          borderSide: BorderSide(color: AppColors.primary),
        ),
        focusedBorder: const OutlineInputBorder(
          borderSide: BorderSide(color: AppColors.primary, width: 3),
        ),
      ),
    );
  }
}

class EstadoConteudoPadrao extends StatelessWidget {
  final bool carregando;
  final String? mensagem;
  final IconData? icone;
  final String? textoBotao;
  final VoidCallback? onPressed;
  final double espacamentoVertical;
  final double tamanhoIcone;
  final double espacamentoMensagem;

  const EstadoConteudoPadrao({
    super.key,
    this.carregando = false,
    this.mensagem,
    this.icone,
    this.textoBotao,
    this.onPressed,
    this.espacamentoVertical = 28,
    this.tamanhoIcone = 42,
    this.espacamentoMensagem = 12,
  }) : assert(carregando || icone != null);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: espacamentoVertical),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (carregando)
              const CircularProgressIndicator()
            else
              Icon(icone, size: tamanhoIcone, color: Colors.black38),
            if (mensagem != null) ...[
              SizedBox(height: espacamentoMensagem),
              Text(
                mensagem!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.black54),
              ),
            ],
            if (textoBotao != null && onPressed != null)
              TextButton(onPressed: onPressed, child: Text(textoBotao!)),
          ],
        ),
      ),
    );
  }
}

class BarraSuperiorPadrao extends StatelessWidget
    implements PreferredSizeWidget {
  final String titulo;
  final List<Widget>? actions;

  const BarraSuperiorPadrao({super.key, required this.titulo, this.actions});

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: Text(titulo),
      backgroundColor: AppColors.background,
      foregroundColor: AppColors.text,
      elevation: 0,
      actions: actions,
      leading: IconButton(
        tooltip: 'Voltar',
        icon: const Icon(Icons.arrow_back),
        onPressed: () {
          Navigator.maybePop(context);
        },
      ),
    );
  }
}
