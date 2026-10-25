import 'package:diacritic/diacritic.dart';

class DadosVeiculo {
  static const cores = [
    'Amarelo',
    'Azul',
    'Bege',
    'Branco',
    'Cinza',
    'Dourado',
    'Fantasia',
    'Gren\u00e1',
    'Laranja',
    'Marrom',
    'Prata',
    'Preto',
    'Rosa',
    'Roxo',
    'Verde',
    'Vermelho',
  ];

  static String normalizarTexto(String valor) =>
      valor.trim().replaceAll(RegExp(' +'), ' ');

  static String normalizarPlaca(String valor) =>
      normalizarTexto(valor).toUpperCase().replaceAll(RegExp('[ -]'), '');

  static String? corPadrao(String valor) {
    final chave = removeDiacritics(normalizarTexto(valor)).toLowerCase();
    for (final cor in cores) {
      if (removeDiacritics(cor).toLowerCase() == chave) return cor;
    }
    return null;
  }

  static String? validarModelo(String? valor) {
    final texto = normalizarTexto(valor ?? '');
    if (texto.length < 2 ||
        texto.length > 100 ||
        RegExp(r'\p{Cc}', unicode: true).hasMatch(valor ?? '') ||
        !RegExp(
          r"^[\p{L}\p{N}][\p{L}\p{N} .+'()/&!,-]*$",
          unicode: true,
        ).hasMatch(texto)) {
      return 'Informe a marca e o modelo v\u00e1lidos';
    }
    return null;
  }

  static String? validarCor(String? valor) {
    final texto = normalizarTexto(valor ?? '');
    if (texto.length < 2 ||
        texto.length > 50 ||
        RegExp(r'\p{Cc}', unicode: true).hasMatch(valor ?? '') ||
        !RegExp(
          r'^[\p{L}]+(?:[ -][\p{L}]+)*$',
          unicode: true,
        ).hasMatch(texto)) {
      return 'Informe uma cor v\u00e1lida';
    }
    return null;
  }

  static String? validarPlaca(String? valor) {
    final recebida = valor ?? '';
    if (recebida.length > 32 ||
        !RegExp(r'^[A-Za-z0-9 -]+$').hasMatch(recebida) ||
        !RegExp(
          r'^[A-Z]{3}(?:\d{4}|\d[A-Z]\d{2})$',
        ).hasMatch(normalizarPlaca(recebida))) {
      return 'Informe uma placa v\u00e1lida';
    }
    return null;
  }
}
