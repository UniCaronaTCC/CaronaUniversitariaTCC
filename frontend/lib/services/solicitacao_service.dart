import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../models/solicitacao_enviada.dart';
import '../models/solicitacao_recebida.dart';
import 'auth_service.dart';

class SolicitacaoService {
  static Future<Map<String, dynamic>> listarEnviadas() async {
    try {
      final token = AuthService.tokenUsuarioLogado;

      if (token == null) {
        return {'sucesso': false, 'mensagem': 'Usuário não está logado'};
      }

      final resposta = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/solicitacoes/enviadas'),
        headers: {'Authorization': 'Bearer $token'},
      );
      final corpo = _decodificarResposta(resposta);

      if (resposta.statusCode == 200) {
        final solicitacoes = <SolicitacaoEnviada>[];
        final dados = corpo['dados'];

        if (dados is List) {
          for (final item in dados) {
            if (item is Map) {
              solicitacoes.add(
                SolicitacaoEnviada.fromJson(Map<String, dynamic>.from(item)),
              );
            }
          }
        }

        return {'sucesso': true, 'dados': solicitacoes};
      }

      return _tratarErro(resposta.statusCode, corpo);
    } catch (erro) {
      return _erroConexao();
    }
  }

  static Future<Map<String, dynamic>> listarRecebidas({int? idCarona}) async {
    try {
      final token = AuthService.tokenUsuarioLogado;

      if (token == null) {
        return {'sucesso': false, 'mensagem': 'Usuário não está logado'};
      }

      final resposta = await http.get(
        Uri.parse(
          idCarona == null
              ? '${ApiConfig.baseUrl}/solicitacoes/recebidas'
              : '${ApiConfig.baseUrl}/caronas/$idCarona/solicitacoes',
        ),
        headers: {'Authorization': 'Bearer $token'},
      );
      final corpo = _decodificarResposta(resposta);

      if (resposta.statusCode == 200) {
        final solicitacoes = <SolicitacaoRecebida>[];
        final dados = corpo['dados'];

        if (dados is List) {
          for (final item in dados) {
            if (item is Map) {
              solicitacoes.add(
                SolicitacaoRecebida.fromJson(Map<String, dynamic>.from(item)),
              );
            }
          }
        }

        return {'sucesso': true, 'dados': solicitacoes};
      }

      return _tratarErro(resposta.statusCode, corpo);
    } catch (erro) {
      return _erroConexao();
    }
  }

  static Future<Map<String, dynamic>> responderSolicitacao({
    required int idSolicitacao,
    required String status,
  }) async {
    try {
      final token = AuthService.tokenUsuarioLogado;

      if (token == null) {
        return {'sucesso': false, 'mensagem': 'Usuário não está logado'};
      }

      final resposta = await http.patch(
        Uri.parse('${ApiConfig.baseUrl}/solicitacoes/$idSolicitacao/status'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'status': status}),
      );
      final corpo = _decodificarResposta(resposta);

      if (resposta.statusCode == 200) {
        return {
          'sucesso': true,
          'mensagem': corpo['mensagem']?.toString() ?? 'Resposta registrada',
        };
      }

      return _tratarErro(resposta.statusCode, corpo);
    } catch (erro) {
      return _erroConexao();
    }
  }

  static Future<Map<String, dynamic>> cancelarSolicitacao(
    int idSolicitacao,
  ) async {
    try {
      final token = AuthService.tokenUsuarioLogado;

      if (token == null) {
        return {'sucesso': false, 'mensagem': 'Usuário não está logado'};
      }

      final resposta = await http.patch(
        Uri.parse('${ApiConfig.baseUrl}/solicitacoes/$idSolicitacao/cancelar'),
        headers: {'Authorization': 'Bearer $token'},
      );
      final corpo = _decodificarResposta(resposta);

      if (resposta.statusCode == 200) {
        return {
          'sucesso': true,
          'mensagem': corpo['mensagem']?.toString() ?? 'Cancelamento realizado',
        };
      }

      return _tratarErro(resposta.statusCode, corpo);
    } catch (erro) {
      return _erroConexao();
    }
  }

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

  static Map<String, dynamic> _tratarErro(
    int statusCode,
    Map<String, dynamic> corpo,
  ) {
    if (statusCode == 401) {
      AuthService.sair();

      return {
        'sucesso': false,
        'mensagem': 'Sua sessão expirou. Entre novamente.',
      };
    }

    return {'sucesso': false, 'mensagem': _obterMensagem(corpo)};
  }

  static Map<String, dynamic> _erroConexao() {
    return {
      'sucesso': false,
      'mensagem': 'Não foi possível conectar ao servidor',
    };
  }
}
