import 'package:flutter/material.dart'; // Importa os componentes visuais do Flutter
import '../config/app_colors.dart'; // Importa as cores padrão do app

class CampoTextoPadrao extends StatelessWidget {
  // Cria um campo de texto reutilizável no app
  final String label; // Texto que aparece dentro do campo
  final TextEditingController?
  controller; // Controla o texto digitado, quando for necessário
  final bool
  obscureText; // Define se o texto será escondido, como em campo de senha
  final TextInputType?
  keyboardType; // Define o tipo de teclado, como e-mail, número etc.

  const CampoTextoPadrao({
    super.key,
    required this.label, // Obriga informar o nome do campo
    this.controller, // Controller é opcional
    this.obscureText = false, // Por padrão, o texto não fica escondido
    this.keyboardType, // Tipo de teclado opcional
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      // Cria o campo onde o usuário digita
      controller: controller, // Liga o campo ao controller recebido
      obscureText: obscureText, // Esconde ou não o texto digitado
      keyboardType: keyboardType, // Define o tipo de teclado exibido
      decoration: InputDecoration(
        // Customiza o visual do campo
        labelText: label, // Mostra o texto do campo
        enabledBorder: const OutlineInputBorder(
          // Borda normal do campo
          borderSide: BorderSide(color: AppColors.primary),
        ),
        focusedBorder: const OutlineInputBorder(
          // Borda quando o usuário clica no campo
          borderSide: BorderSide(color: AppColors.primary, width: 3),
        ),
      ),
    );
  }
}

class BotaoPadrao extends StatelessWidget {
  // Cria um botão reutilizável no app
  final String texto; // Texto que aparece no botão
  final VoidCallback? onPressed; // Função executada ao clicar no botão

  const BotaoPadrao({
    super.key,
    required this.texto, // Obriga informar o texto do botão
    required this.onPressed, // Obriga informar a ação do botão
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      // Controla o tamanho do botão
      width: double.infinity, // Faz o botão ocupar toda a largura disponível
      child: ElevatedButton(
        // Cria o botão elevado
        style: ElevatedButton.styleFrom(
          backgroundColor: Theme.of(context)
              .colorScheme
              .primaryContainer, // Cor de fundo do botão, puxada do tema global
          foregroundColor: Theme.of(
            context,
          ).colorScheme.primary, // Cor do texto do botão, puxada do tema global
        ),
        onPressed: onPressed, // Executa a função recebida ao clicar
        child: Text(texto), // Mostra o texto recebido no botão
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

  const BarraSuperiorPadrao({super.key, required this.titulo});

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: Text(titulo),
      backgroundColor: AppColors.background,
      foregroundColor: AppColors.text,
      elevation: 0,
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
