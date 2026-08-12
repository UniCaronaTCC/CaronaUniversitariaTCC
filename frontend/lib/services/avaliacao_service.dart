import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import 'auth_service.dart';

class AvaliacaoService {
  static Future<Map<String, dynamic>> enviar({
    required int idSolicitacao,
    required int nota,
    String? comentario,
  }) async {
    final token = AuthService.tokenUsuarioLogado;

    if (token == null) {
      return {'sucesso': false, 'mensagem': 'Usuário não está logado'};
    }

    try {
      final resposta = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/avaliacoes'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'idSolicitacao': idSolicitacao,
          'nota': nota,
          'comentario': comentario,
        }),
      );
      final corpo = _decodificarResposta(resposta.body);

      if (resposta.statusCode == 200 || resposta.statusCode == 201) {
        return {
          'sucesso': true,
          'mensagem':
              corpo['mensagem']?.toString() ?? 'Avaliação enviada com sucesso',
        };
      }

      if (resposta.statusCode == 401) {
        await AuthService.sair();
      }

      return {
        'sucesso': false,
        'mensagem':
            corpo['mensagem'] ?? corpo['message'] ?? 'Erro ao enviar avaliação',
      };
    } catch (erro) {
      return {
        'sucesso': false,
        'mensagem': 'Não foi possível conectar ao servidor',
      };
    }
  }

  static Future<Map<String, dynamic>> listarRecebidas(
    int idUsuario, {
    int pagina = 1,
  }) async {
    final token = AuthService.tokenUsuarioLogado;

    if (token == null) {
      return {'sucesso': false, 'mensagem': 'Usuário não está logado'};
    }

    try {
      final url = Uri.parse(
        '${ApiConfig.baseUrl}/usuarios/$idUsuario/avaliacoes?pagina=$pagina',
      );
      final resposta = await http.get(
        url,
        headers: {'Authorization': 'Bearer $token'},
      );
      final corpo = _decodificarResposta(resposta.body);

      if (resposta.statusCode == 200 && corpo['dados'] is Map) {
        return {
          'sucesso': true,
          'dados': Map<String, dynamic>.from(corpo['dados']),
        };
      }

      if (resposta.statusCode == 401) {
        await AuthService.sair();
      }

      return {
        'sucesso': false,
        'mensagem':
            corpo['mensagem'] ??
            corpo['message'] ??
            'Erro ao buscar avaliações',
      };
    } catch (erro) {
      return {
        'sucesso': false,
        'mensagem': 'Não foi possível conectar ao servidor',
      };
    }
  }

  static Map<String, dynamic> _decodificarResposta(String corpo) {
    if (corpo.isEmpty) {
      return {};
    }

    try {
      final resultado = jsonDecode(corpo);

      return resultado is Map<String, dynamic> ? resultado : {};
    } catch (erro) {
      return {};
    }
  }
}
