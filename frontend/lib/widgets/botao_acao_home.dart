import 'package:flutter/material.dart'; // Importa os componentes visuais do Flutter
import '../config/app_colors.dart'; // Importa as cores principais do app

class BotaoAcaoHome extends StatelessWidget {
  // Cria um botão grande reutilizável para a tela inicial
  final String texto; // Texto que aparece no botão
  final IconData icone; // Ícone que aparece no botão
  final VoidCallback onPressed; // Função executada ao clicar no botão

  const BotaoAcaoHome({
    super.key,
    required this.texto,
    required this.icone,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      // Controla o tamanho do botão
      width: double.infinity, // Faz o botão ocupar toda a largura disponível
      height: 82, // Define a altura do botão
      child: ElevatedButton.icon(
        // Cria botão com ícone e texto
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary, // Cor de fundo roxa
          foregroundColor: Colors.white, // Cor do texto e do ícone
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(
              20,
            ), // Arredonda as bordas do botão
          ),
          elevation: 6, // Cria sombra no botão
        ),
        onPressed: onPressed, // Executa a função recebida ao clicar
        icon: Icon(icone, size: 32),
        label: Text(
          texto,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
