import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../models/pagamento_pix.dart';
import 'auth_service.dart';

class PagamentoService {
  final http.Client _cliente;

  PagamentoService({http.Client? cliente})
    : _cliente = cliente ?? http.Client();

  Future<Map<String, dynamic>> criarOuObterPix(int idSolicitacao) async {
    final token = AuthService.tokenUsuarioLogado;

    if (token == null) {
      return {'sucesso': false, 'mensagem': 'Usuário não está logado'};
    }

    try {
      final resposta = await _cliente.post(
        Uri.parse(
          '${ApiConfig.baseUrl}/pagamentos/solicitacoes/$idSolicitacao/pix',
        ),
        headers: {'Authorization': 'Bearer $token'},
      );
      final corpo = _decodificarResposta(resposta);

      if (resposta.statusCode >= 200 && resposta.statusCode < 300) {
        final dados = corpo['dados'];

        if (dados is! Map) {
          throw const FormatException('Resposta de pagamento inválida');
        }

        return {
          'sucesso': true,
          'dados': PagamentoPix.fromJson(Map<String, dynamic>.from(dados)),
        };
      }

      if (resposta.statusCode == 401) {
        await AuthService.sair();
      }

      return {
        'sucesso': false,
        'mensagem':
            corpo['mensagem']?.toString() ??
            corpo['message']?.toString() ??
            'Não foi possível preparar o pagamento',
      };
    } on FormatException {
      return {
        'sucesso': false,
        'mensagem': 'O servidor retornou um pagamento inválido',
      };
    } catch (erro) {
      return {
        'sucesso': false,
        'mensagem': 'Não foi possível conectar ao servidor',
      };
    }
  }

  Map<String, dynamic> _decodificarResposta(http.Response resposta) {
    if (resposta.body.isEmpty) {
      return {};
    }

    final resultado = jsonDecode(resposta.body);
    return resultado is Map
        ? Map<String, dynamic>.from(resultado)
        : <String, dynamic>{};
  }
}
