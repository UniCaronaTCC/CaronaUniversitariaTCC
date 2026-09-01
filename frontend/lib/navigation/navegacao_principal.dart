import 'package:flutter/material.dart';

class NavegacaoPrincipal {
  const NavegacaoPrincipal._();

  static const rotaChat = '/chat';
  static const rotaCaronas = '/caronas';
  static const rotaPerfil = '/perfil';

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

    if (indice == 1) {
      await navigator.pushNamedAndRemoveUntil(rotaChat, (rota) => rota.isFirst);
      return;
    }

    if (indice == 2) {
      await navigator.pushNamedAndRemoveUntil(
        rotaCaronas,
        (rota) => rota.isFirst,
      );
      return;
    }

    if (indice == 3) {
      await navigator.pushNamedAndRemoveUntil(
        rotaPerfil,
        (rota) => rota.isFirst,
      );
    }
  }
}
