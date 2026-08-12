import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../models/instituicao.dart';

class InstituicaoService {
  static Future<List<Instituicao>> buscar(
    String termo, {
    String? cidade,
    String? uf,
    double? latitude,
    double? longitude,
  }) async {
    if (termo.trim().length < 2) {
      return [];
    }

    try {
      final parametros = <String, String>{'busca': termo.trim()};

      if (cidade?.trim().isNotEmpty == true) {
        parametros['cidade'] = cidade!.trim();
      }

      if (uf?.trim().isNotEmpty == true) {
        parametros['uf'] = uf!.trim();
      }

      if (latitude != null && longitude != null) {
        parametros['latitude'] = latitude.toString();
        parametros['longitude'] = longitude.toString();
      }

      final url = Uri.parse(
        '${ApiConfig.baseUrl}/instituicoes',
      ).replace(queryParameters: parametros);
      final resposta = await http.get(url);

      if (resposta.statusCode != 200 || resposta.body.isEmpty) {
        return [];
      }

      final json = jsonDecode(resposta.body);
      final dados = json['dados'];

      if (dados is! List) {
        return [];
      }

      return dados
          .whereType<Map<String, dynamic>>()
          .map(Instituicao.fromJson)
          .toList();
    } catch (_) {
      return [];
    }
  }
}
