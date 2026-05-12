import 'package:flutter/material.dart'; // importa os componentes visuais do Flutter
import 'package:uni_carona/auth/cadastro.dart';
import 'auth/login.dart'; // importa a tela de login
import 'config/app_theme.dart'; // importa o tema visual do app

void main() { // função principal, onde o app começa a rodar
  runApp( // inicia o aplicativo Flutter
    MaterialApp( // cria a estrutura principal do aplicativo
      debugShowCheckedModeBanner: false, // remove a faixa de "debug" do canto da tela
      theme: AppTheme.lightTheme, // aplica o tema visual claro definido em app_theme.dart
      home: const LoginTela(), // define a tela de login como tela inicial do app
    ),
  );
}