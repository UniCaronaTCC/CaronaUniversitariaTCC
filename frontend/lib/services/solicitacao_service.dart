import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../models/solicitacao_enviada.dart';
import '../models/solicitacao_recebida.dart';
import 'auth_service.dart';

class SolicitacaoService {
  static final ValueNotifier<int> totalSolicitacoesPendentes = ValueNotifier(0);
  static Timer? _timerSolicitacoesPendentes;

  static Future<void> iniciarContadorSolicitacoesPendentes() async {
    if (AuthService.tokenUsuarioLogado == null) {
      pararContadorSolicitacoesPendentes();
      return;
    }

    await atualizarTotalSolicitacoesPendentes();

    if (_timerSolicitacoesPendentes?.isActive == true) {
      return;
    }

    _timerSolicitacoesPendentes = Timer.periodic(
      const Duration(seconds: 30),
      (_) => unawaited(atualizarTotalSolicitacoesPendentes()),
    );
  }

  static Future<void> atualizarTotalSolicitacoesPendentes() async {
    if (AuthService.tokenUsuarioLogado == null) {
      pararContadorSolicitacoesPendentes();
      return;
    }

    final resultados = await Future.wait([listarRecebidas(), listarEnviadas()]);
    final recebidas = resultados[0]['dados'];
    final enviadas = resultados[1]['dados'];

    if (resultados[0]['sucesso'] == true &&
        resultados[1]['sucesso'] == true &&
        recebidas is List<SolicitacaoRecebida> &&
        enviadas is List<SolicitacaoEnviada>) {
      sincronizarTotalSolicitacoesPendentes(recebidas, enviadas: enviadas);
    }
  }

  static void sincronizarTotalSolicitacoesPendentes(
    Iterable<SolicitacaoRecebida> solicitacoes, {
    Iterable<SolicitacaoEnviada> enviadas = const [],
  }) {
    final recebidasPendentes = solicitacoes
        .where(
          (solicitacao) =>
              solicitacao.status == 'PENDENTE' &&
              !solicitacao.caronaFinalizada &&
              !solicitacao.cancelada,
        )
        .length;
    final aceitesAguardandoAcao = enviadas
        .where((solicitacao) => solicitacao.aceiteAguardandoAcao)
        .length;

    totalSolicitacoesPendentes.value =
        recebidasPendentes + aceitesAguardandoAcao;
  }

  static void pararContadorSolicitacoesPendentes({bool limparTotal = true}) {
    _timerSolicitacoesPendentes?.cancel();
    _timerSolicitacoesPendentes = null;

    if (limparTotal) {
      totalSolicitacoesPendentes.value = 0;
    }
  }

  static Future<Map<String, dynamic>> listarEnviadas() async {
    try {
      final resposta = await AuthService.enviarComToken(
        (token) => http.get(
          Uri.parse('${ApiConfig.baseUrl}/solicitacoes/enviadas'),
          headers: {'Authorization': 'Bearer $token'},
        ),
      );

      if (resposta == null) {
        return {'sucesso': false, 'mensagem': 'Usuário não está logado'};
      }
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

      return await _tratarErro(resposta.statusCode, corpo);
    } catch (erro) {
      return _erroConexao();
    }
  }

  static Future<Map<String, dynamic>> listarRecebidas({int? idCarona}) async {
    try {
      final url = Uri.parse(
        idCarona == null
            ? '${ApiConfig.baseUrl}/solicitacoes/recebidas'
            : '${ApiConfig.baseUrl}/caronas/$idCarona/solicitacoes',
      );
      final resposta = await AuthService.enviarComToken(
        (token) => http.get(url, headers: {'Authorization': 'Bearer $token'}),
      );

      if (resposta == null) {
        return {'sucesso': false, 'mensagem': 'Usuário não está logado'};
      }
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

      return await _tratarErro(resposta.statusCode, corpo);
    } catch (erro) {
      return _erroConexao();
    }
  }

  static Future<Map<String, dynamic>> responderSolicitacao({
    required int idSolicitacao,
    required String status,
  }) async {
    try {
      final resposta = await AuthService.enviarComToken(
        (token) => http.patch(
          Uri.parse('${ApiConfig.baseUrl}/solicitacoes/$idSolicitacao/status'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode({'status': status}),
        ),
      );

      if (resposta == null) {
        return {'sucesso': false, 'mensagem': 'Usuário não está logado'};
      }

      final corpo = _decodificarResposta(resposta);

      if (resposta.statusCode == 200) {
        return {
          'sucesso': true,
          'mensagem': corpo['mensagem']?.toString() ?? 'Resposta registrada',
        };
      }

      return await _tratarErro(resposta.statusCode, corpo);
    } catch (erro) {
      return _erroConexao();
    }
  }

  static Future<Map<String, dynamic>> cancelarSolicitacao(
    int idSolicitacao,
  ) async {
    try {
      final resposta = await AuthService.enviarComToken(
        (token) => http.patch(
          Uri.parse(
            '${ApiConfig.baseUrl}/solicitacoes/$idSolicitacao/cancelar',
          ),
          headers: {'Authorization': 'Bearer $token'},
        ),
      );

      if (resposta == null) {
        return {'sucesso': false, 'mensagem': 'Usuário não está logado'};
      }

      final corpo = _decodificarResposta(resposta);

      if (resposta.statusCode == 200) {
        return {
          'sucesso': true,
          'mensagem': corpo['mensagem']?.toString() ?? 'Cancelamento realizado',
        };
      }

      return await _tratarErro(resposta.statusCode, corpo);
    } catch (erro) {
      return _erroConexao();
    }
  }

  // Solicita uma vaga usando um ponto que já existe na carona.
  static Future<Map<String, dynamic>> solicitarVagaComPontoExistente({
    required int idCarona,
    required int idPontoEmbarque,
  }) {
    return _solicitarVaga(
      idCarona: idCarona,
      corpo: {
        'tipoPontoEmbarque': 'EXISTENTE',
        'idPontoEmbarque': idPontoEmbarque,
      },
    );
  }

  // Solicita uma vaga propondo um novo ponto de embarque.
  static Future<Map<String, dynamic>> solicitarVagaComNovoPonto({
    required int idCarona,
    required String localEmbarque,
    required double embarqueLatitude,
    required double embarqueLongitude,
  }) {
    return _solicitarVaga(
      idCarona: idCarona,
      corpo: {
        'tipoPontoEmbarque': 'NOVO_SOLICITADO',
        'localEmbarque': localEmbarque,
        'embarqueLatitude': embarqueLatitude,
        'embarqueLongitude': embarqueLongitude,
      },
    );
  }

  static Future<Map<String, dynamic>> _solicitarVaga({
    required int idCarona,
    required Map<String, dynamic> corpo,
  }) async {
    try {
      final resposta = await AuthService.enviarComToken(
        (token) => http.post(
          Uri.parse('${ApiConfig.baseUrl}/caronas/$idCarona/solicitacoes'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode(corpo),
        ),
      );

      if (resposta == null) {
        return {'sucesso': false, 'mensagem': 'Usuário não está logado'};
      }

      final respostaJson = _decodificarResposta(resposta);

      if (resposta.statusCode == 200 || resposta.statusCode == 201) {
        return {
          'sucesso': true,
          'mensagem':
              respostaJson['mensagem']?.toString() ??
              'Solicitação enviada ao motorista',
          'dados': respostaJson['dados'],
        };
      }

      return await _tratarErro(resposta.statusCode, respostaJson);
    } catch (erro) {
      return _erroConexao();
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

  static Future<Map<String, dynamic>> _tratarErro(
    int statusCode,
    Map<String, dynamic> corpo,
  ) async {
    if (statusCode == 401) {
      pararContadorSolicitacoesPendentes();
      await AuthService.sair();

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
