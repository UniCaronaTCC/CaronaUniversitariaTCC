import 'package:flutter/material.dart'; // importa os componentes visuais do Flutter
import 'app_colors.dart'; // importa o arquivo onde estão as cores principais do app

class AppTheme { // cria a classe responsável por guardar o tema visual do app
  static ThemeData lightTheme = ThemeData( // cria o tema claro do aplicativo
    scaffoldBackgroundColor: AppColors.background, // define a cor de fundo padrão das telas
    colorScheme: ColorScheme.fromSeed( // cria um conjunto de cores baseado em uma cor principal
      seedColor: AppColors.primary, // usa a cor principal do app como base do tema
    ),
  );
}