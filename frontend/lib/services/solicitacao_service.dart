import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import 'auth_service.dart';

class SolicitacaoService {
  static Future<Map<String, dynamic>> solicitarVaga({
    required int idCarona,
    required String localEmbarque,
    required double embarqueLatitude,
    required double embarqueLongitude,
  }) async {
    try {
      final token = AuthService.tokenUsuarioLogado;

      if (token == null) {
        return {'sucesso': false, 'mensagem': 'Usuário não está logado'};
      }

      final url = Uri.parse(
        '${ApiConfig.baseUrl}/caronas/$idCarona/solicitacoes',
      );
      final resposta = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'localEmbarque': localEmbarque,
          'embarqueLatitude': embarqueLatitude,
          'embarqueLongitude': embarqueLongitude,
        }),
      );
      final corpo = _decodificarResposta(resposta);

      if (resposta.statusCode == 200 || resposta.statusCode == 201) {
        return {
          'sucesso': true,
          'mensagem':
              corpo['mensagem']?.toString() ??
              'Solicitação enviada ao motorista',
          'dados': corpo['dados'],
        };
      }

      if (resposta.statusCode == 401) {
        AuthService.sair();

        return {
          'sucesso': false,
          'mensagem': 'Sua sessão expirou. Entre novamente.',
        };
      }

      return {'sucesso': false, 'mensagem': _obterMensagem(corpo)};
    } catch (erro) {
      return {
        'sucesso': false,
        'mensagem': 'Não foi possível conectar ao servidor',
      };
    }
  }

  static Map<String, dynamic> _decodificarResposta(http.Response resposta) {
    if (resposta.body.isEmpty) {
      return {};
    }

    try {
      final resultado = jsonDecode(resposta.body);

      return resultado is Map<String, dynamic> ? resultado : {};
    } catch (erro) {
      return {};
    }
  }

  static String _obterMensagem(Map<String, dynamic> dados) {
    final mensagem = dados['mensagem'] ?? dados['message'];

    return mensagem?.toString() ?? 'Erro ao solicitar vaga';
  }
}
