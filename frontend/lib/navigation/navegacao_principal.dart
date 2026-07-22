import 'package:flutter/material.dart';

class NavegacaoPrincipal {
  const NavegacaoPrincipal._();

  static const rotaCaronas = '/caronas';

  static Future<void> selecionar(
    BuildContext context,
    int indice, {
    required int indiceAtual,
  }) async {
    if (indice == indiceAtual) {
      return;
    }

    final navigator = Navigator.of(context);

    if (indice == 0) {
      navigator.popUntil((rota) => rota.isFirst);
      return;
    }

    if (indice == 2) {
      await navigator.pushNamedAndRemoveUntil(
        rotaCaronas,
        (rota) => rota.isFirst,
      );
    }
  }
}
