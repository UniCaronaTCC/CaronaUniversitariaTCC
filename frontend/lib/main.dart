import 'package:flutter/material.dart';
import 'package:uni_carona/mapa/screens/mapa_screen.dart';

import 'auth/login.dart';
import 'config/app_theme.dart';
import 'home/minhas_caronas.dart';
import 'navigation/navegacao_principal.dart';

void main() {
  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const TesteMapa(),
      routes: {
        NavegacaoPrincipal.rotaCaronas: (_) => const MinhasCaronasTela(),
      },
    ),
  );
}