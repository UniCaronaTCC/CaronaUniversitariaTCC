import 'package:flutter/material.dart';

import 'auth/login.dart';
import 'config/app_theme.dart';
import 'home/minhas_caronas.dart';
import 'navigation/navegacao_principal.dart';

void main() {
  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const LoginTela(),
      routes: {
        NavegacaoPrincipal.rotaCaronas: (_) => const MinhasCaronasTela(),
      },
    ),
  );
}