import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/campus_destino.dart';

class CatalogoCidadesService {
  final AssetBundle? bundle;
  static List<CidadeCampus>? _cache;

  const CatalogoCidadesService({this.bundle});

  Future<List<CidadeCampus>> listar() async {
    if (bundle == null && _cache != null) return _cache!;
    final texto = await (bundle ?? rootBundle).loadString(
      'assets/dados/municipios_ibge.json',
    );
    final json = jsonDecode(texto);
    if (json is! Map<String, dynamic> || json['municipios'] is! List) {
      throw const FormatException('Catalogo de cidades invalido');
    }
    final cidades = <CidadeCampus>[];
    final identidades = <String>{};
    final ids = <int>{};
    for (final item in json['municipios'] as List) {
      if (item is! Map<String, dynamic> ||
          item['id'] is! int ||
          item['nome'] is! String ||
          item['uf'] is! String) {
        throw const FormatException('Municipio invalido');
      }
      final nome = (item['nome'] as String).trim();
      final uf = item['uf'] as String;
      if (nome.length < 2 ||
          nome.length > 100 ||
          (item['id'] as int) <= 0 ||
          !CidadeCampus.estados.containsKey(uf) ||
          !ids.add(item['id'] as int) ||
          !identidades.add('${normalizarDestino(nome)}|$uf')) {
        throw const FormatException('Municipio invalido ou duplicado');
      }
      cidades.add(CidadeCampus(nome, uf));
    }
    if (cidades.isEmpty) throw const FormatException('Catalogo vazio');
    cidades.sort((a, b) {
      final nome = normalizarDestino(
        a.cidade,
      ).compareTo(normalizarDestino(b.cidade));
      return nome != 0 ? nome : a.uf.compareTo(b.uf);
    });
    final resultado = List<CidadeCampus>.unmodifiable(cidades);
    if (bundle == null) _cache = resultado;
    return resultado;
  }
}
