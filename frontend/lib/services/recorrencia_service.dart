import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/recorrencia_carona.dart';
import 'auth_service.dart';

class RecorrenciaService {
  static Future<List<RecorrenciaCarona>> listar() async {
    final dados = await _enviar();
    return (dados['dados'] as List)
        .map(
          (item) => RecorrenciaCarona.fromJson(
            Map<String, dynamic>.from(item as Map),
          ),
        )
        .toList();
  }

  static Future<void> alterarEstado(int id, bool ativa) async {
    await _enviar(id: id, ativa: ativa);
  }

  static Future<Map<String, dynamic>> _enviar({int? id, bool? ativa}) async {
    final resposta = await AuthService.enviarComToken((token) {
      final url = Uri.parse(
        '${ApiConfig.baseUrl}/recorrencias${id == null ? '' : '/$id/estado'}',
      );
      final headers = {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      };
      return (id == null
              ? http.get(url, headers: headers)
              : http.patch(
                  url,
                  headers: headers,
                  body: jsonEncode({'ativa': ativa}),
                ))
          .timeout(const Duration(seconds: 15));
    });
    if (resposta == null) {
      throw Exception('Entre novamente para gerenciar suas recorrências');
    }
    final corpo = jsonDecode(resposta.body) as Map<String, dynamic>;
    if (resposta.statusCode != 200) {
      throw Exception(
        corpo['message'] ?? 'Não foi possível atualizar as recorrências',
      );
    }
    return corpo;
  }
}
