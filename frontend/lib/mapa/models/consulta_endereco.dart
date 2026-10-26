import 'package:diacritic/diacritic.dart';

class ConsultaEndereco {
  final String texto;
  final String? logradouro;
  final String? numero;
  final String contexto;

  const ConsultaEndereco._(
    this.texto,
    this.logradouro,
    this.numero,
    this.contexto,
  );

  static String normalizar(String texto) => removeDiacritics(texto)
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
      .trim()
      .replaceAll(RegExp(r'\s+'), ' ');

  static String normalizarLogradouro(String texto) {
    final normalizado = normalizar(texto);
    final partes = normalizado.split(' ');
    const prefixos = {
      'r': 'rua',
      'av': 'avenida',
      'tv': 'travessa',
      'trav': 'travessa',
      'al': 'alameda',
    };
    partes[0] = prefixos[partes[0]] ?? partes[0];
    return partes.join(' ');
  }

  factory ConsultaEndereco(String texto, {bool interpretarNumero = true}) {
    final original = texto.trim();
    final primeiraParte = original.split(',').first;
    final normalizado = normalizarLogradouro(primeiraParte);
    final ehLogradouro = RegExp(
      r'^(rua|avenida|travessa|alameda|praca|estrada|largo)\s+',
    ).hasMatch(normalizado);
    if (!ehLogradouro) {
      return ConsultaEndereco._(original, null, null, original);
    }

    final comVirgula = RegExp(
      r'^(.+?),\s*(\d{1,6}[a-zA-Z]?)(?:\s*,\s*(.+))?$',
    ).firstMatch(original);
    final noFinal = RegExp(
      r'^(.+\S)\s+(\d{1,6}[a-zA-Z]?)$',
    ).firstMatch(original);
    final encontrado = interpretarNumero ? comVirgula ?? noFinal : null;
    if (encontrado != null) {
      final rua = encontrado.group(1)!.trim();
      // "Rua 7" e identificador do logradouro, nao um numero de casa.
      final palavrasRua = normalizarLogradouro(rua).split(' ');
      if (palavrasRua.length > 1 &&
          palavrasRua.skip(1).any((p) => RegExp(r'[a-z]').hasMatch(p))) {
        return ConsultaEndereco._(
          original,
          rua,
          encontrado.group(2)!.toUpperCase(),
          comVirgula?.group(3)?.trim() ?? '',
        );
      }
    }
    return ConsultaEndereco._(
      original,
      primeiraParte.trim(),
      null,
      original.contains(',')
          ? original.substring(original.indexOf(',') + 1).trim()
          : '',
    );
  }

  String? get semNumero => numero == null
      ? null
      : [logradouro!, if (contexto.isNotEmpty) contexto].join(', ');

  bool cidadeExplicita(String cidade) {
    final nome = normalizar(cidade);
    if (nome.isEmpty) return false;
    return RegExp(
      '(?:^| )${RegExp.escape(nome)}'
      r'(?: |$)',
    ).hasMatch(normalizar(contexto));
  }
}
