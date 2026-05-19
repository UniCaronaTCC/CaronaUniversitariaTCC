import 'package:flutter/material.dart'; // Importa os componentes visuais do Flutter
import '../config/app_colors.dart'; // Importa as cores principais do app

class TelaInicial extends StatelessWidget { // Cria a tela inicial do app
  const TelaInicial({super.key}); // Construtor da tela inicial

  @override
  Widget build(BuildContext context) { // Tudo que aparece visualmente na tela fica aqui
    return Scaffold( // Estrutura base da tela
      backgroundColor: AppColors.background, // Define a cor de fundo da tela

      body: SafeArea( // Evita que o conteúdo fique embaixo da barra de status do celular
        child: Padding(
          padding: const EdgeInsets.all(24), // Espaçamento interno da tela
          child: Column( // Organiza os elementos um embaixo do outro
            crossAxisAlignment: CrossAxisAlignment.start, // Alinha os itens à esquerda
            children: const [
              Text(
                'Olá, usuário',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),

              SizedBox(height: 8),

              Text(
                'Para onde você vai hoje?',
                style: TextStyle(
                  fontSize: 20,
                  color: AppColors.text,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}