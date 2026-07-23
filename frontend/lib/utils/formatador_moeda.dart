import 'package:flutter/services.dart';

class FormatadorMoedaReal extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue valorAntigo,
    TextEditingValue valorNovo,
  ) {
    final numeros = valorNovo.text.replaceAll(RegExp(r'[^0-9]'), '');

    if (numeros.isEmpty) {
      return const TextEditingValue(
        text: '',
        selection: TextSelection.collapsed(offset: 0),
      );
    }

    final textoFormatado = _formatarCentavos(int.parse(numeros));

    return TextEditingValue(
      text: textoFormatado,
      selection: TextSelection.collapsed(offset: textoFormatado.length),
    );
  }
}

String formatarDoubleComoMoedaReal(double valor) {
  return _formatarCentavos((valor * 100).round());
}

// Converte "R$ 1.234,56" para 1234.56.
double converterMoedaRealParaDouble(String valorFormatado) {
  final numeros = valorFormatado.replaceAll(RegExp(r'[^0-9]'), '');

  if (numeros.isEmpty) {
    return 0;
  }

  return int.parse(numeros) / 100;
}

String _formatarCentavos(int valorEmCentavos) {
  final reais = valorEmCentavos ~/ 100;
  final centavos = valorEmCentavos % 100;
  final caracteres = reais.toString().split('').reversed.toList();
  final partes = <String>[];

  for (int indice = 0; indice < caracteres.length; indice++) {
    if (indice > 0 && indice % 3 == 0) {
      partes.add('.');
    }

    partes.add(caracteres[indice]);
  }

  return 'R\$ ${partes.reversed.join()},${centavos.toString().padLeft(2, '0')}';
}
