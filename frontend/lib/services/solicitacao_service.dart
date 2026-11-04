import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../models/solicitacao_enviada.dart';
import '../models/solicitacao_recebida.dart';
import 'auth_service.dart';
import 'cliente_http_com_prazo.dart';
import 'memoria_solicitacoes.dart';

class SolicitacaoService {
  static final ValueNotifier<int> totalSolicitacoesPendentes = ValueNotifier(0);
  static Timer? _timerSolicitacoesPendentes;
  static int _geracaoContador = 0;

  static EscopoSolicitacoes? get _escopoAtual {
    final id = int.tryParse(AuthService.usuarioLogado?['id']?.toString() ?? '');
    return AuthService.estaLogado && id != null && id > 0
        ? (id, AuthService.versaoSessao)
        : null;
  }

  static ListasSolicitacoes? lerListas() {
    final escopo = _escopoAtual;
    return escopo == null
        ? null
        : MemoriaSolicitacoes.compartilhada.ler(escopo);
  }

  static bool get listasConfirmadas {
    final escopo = _escopoAtual;
    return escopo != null &&
        MemoriaSolicitacoes.compartilhada.confirmada(escopo);
  }

  static Future<Map<String, dynamic>> atualizarListas({
    bool invalidar = false,
  }) {
    final escopo = _escopoAtual;
    if (escopo == null) {
      return Future.value({
        'sucesso': false,
        'mensagem': 'Usuário não está logado',
      });
    }
    final memoria = MemoriaSolicitacoes.compartilhada;
    if (invalidar) memoria.invalidar(escopo);
    return memoria.atualizar(
      escopo,
      recebidas: () => listarRecebidas(),
      enviadas: listarEnviadas,
    );
  }

  static void _invalidarListas(EscopoSolicitacoes? escopo) {
    if (escopo != null && escopo == _escopoAtual) {
      MemoriaSolicitacoes.compartilhada.invalidar(escopo);
    }
  }

  static Future<void> iniciarContadorSolicitacoesPendentes() async {
    if (AuthService.tokenUsuarioLogado == null) {
      pararContadorSolicitacoesPendentes();
      return;
    }

    final escopo = _escopoAtual;
    if (escopo == null) return;
    final geracao = _geracaoContador;

    await atualizarTotalSolicitacoesPendentes();

    if (escopo != _escopoAtual || geracao != _geracaoContador) return;

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

    final escopo = _escopoAtual;
    if (escopo == null) return;
    final geracao = _geracaoContador;
    final resultado = await atualizarListas();
    if (escopo != _escopoAtual || geracao != _geracaoContador) return;
    final listas = resultado['dados'];
    if (resultado['sucesso'] == true &&
        listas is ListasSolicitacoes &&
        listasConfirmadas &&
        identical(lerListas(), listas)) {
      sincronizarTotalSolicitacoesPendentes(
        listas.recebidas,
        enviadas: listas.enviadas,
      );
    }
  }

  static void sincronizarTotalSolicitacoesPendentes(
    Iterable<SolicitacaoRecebida> solicitacoes, {
    Iterable<SolicitacaoEnviada> enviadas = const [],
  }) {
    final recebidasPendentes = solicitacoes
        .where(
          (solicitacao) =>
              solicitacao.status == 'PENDENTE' && !solicitacao.arquivada,
        )
        .length;
    final aceitesAguardandoAcao = enviadas
        .where((solicitacao) => solicitacao.aceiteAguardandoAcao)
        .length;

    totalSolicitacoesPendentes.value =
        recebidasPendentes + aceitesAguardandoAcao;
  }

  static void pararContadorSolicitacoesPendentes({bool limparTotal = true}) {
    _geracaoContador++;
    _timerSolicitacoesPendentes?.cancel();
    _timerSolicitacoesPendentes = null;

    if (limparTotal) {
      totalSolicitacoesPendentes.value = 0;
    }
  }

  static Future<Map<String, dynamic>> listarEnviadas() async {
    final cliente = ClienteHttpComPrazo();
    try {
      final resposta = await AuthService.enviarComToken(
        (token) => cliente.get(
          Uri.parse('${ApiConfig.baseUrl}/solicitacoes/enviadas'),
          headers: {'Authorization': 'Bearer $token'},
        ),
      ).timeout(const Duration(seconds: 20));

      if (resposta == null) {
        return {'sucesso': false, 'mensagem': 'Usuário não está logado'};
      }
      final corpo = _decodificarResposta(resposta);

      if (resposta.statusCode == 200) {
        final solicitacoes = <SolicitacaoEnviada>[];
        final dados = corpo['dados'];

        if (corpo['sucesso'] == false || dados is! List) {
          throw const FormatException('Lista de solicitações inválida');
        }
        for (final item in dados) {
          if (item is! Map) {
            throw const FormatException('Solicitação inválida');
          }
          solicitacoes.add(
            SolicitacaoEnviada.fromJson(Map<String, dynamic>.from(item)),
          );
        }

        return {'sucesso': true, 'dados': solicitacoes};
      }

      return await _tratarErro(resposta.statusCode, corpo);
    } on FormatException {
      return {
        'sucesso': false,
        'mensagem':
            'O servidor retornou uma resposta inválida ao consultar suas solicitações. Tente novamente.',
      };
    } catch (erro) {
      return _erroConexao();
    } finally {
      cliente.close();
    }
  }

  static Future<Map<String, dynamic>> listarRecebidas({int? idCarona}) async {
    final cliente = ClienteHttpComPrazo();
    try {
      final url = Uri.parse(
        idCarona == null
            ? '${ApiConfig.baseUrl}/solicitacoes/recebidas'
            : '${ApiConfig.baseUrl}/caronas/$idCarona/solicitacoes',
      );
      final resposta = await AuthService.enviarComToken(
        (token) =>
            cliente.get(url, headers: {'Authorization': 'Bearer $token'}),
      ).timeout(const Duration(seconds: 20));

      if (resposta == null) {
        return {'sucesso': false, 'mensagem': 'Usuário não está logado'};
      }
      final corpo = _decodificarResposta(resposta);

      if (resposta.statusCode == 200) {
        final solicitacoes = <SolicitacaoRecebida>[];
        final dados = corpo['dados'];

        if (corpo['sucesso'] == false || dados is! List) {
          throw const FormatException('Lista de solicitacoes invalida');
        }
        for (final item in dados) {
          if (item is! Map) {
            throw const FormatException('Solicitacao invalida');
          }
          solicitacoes.add(
            SolicitacaoRecebida.fromJson(Map<String, dynamic>.from(item)),
          );
        }

        return {'sucesso': true, 'dados': solicitacoes};
      }

      return await _tratarErro(resposta.statusCode, corpo);
    } on FormatException {
      return {
        'sucesso': false,
        'mensagem':
            'O servidor retornou uma resposta inválida ao consultar suas solicitações. Tente novamente.',
      };
    } catch (erro) {
      return _erroConexao();
    } finally {
      cliente.close();
    }
  }

  static Future<Map<String, dynamic>> responderSolicitacao({
    required int idSolicitacao,
    required String status,
  }) async {
    final escopo = _escopoAtual;
    _invalidarListas(escopo);
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
    } finally {
      _invalidarListas(escopo);
    }
  }

  static Future<Map<String, dynamic>> cancelarSolicitacao(
    int idSolicitacao,
  ) async {
    final escopo = _escopoAtual;
    _invalidarListas(escopo);
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
    } finally {
      _invalidarListas(escopo);
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
    final escopo = _escopoAtual;
    _invalidarListas(escopo);
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
    } finally {
      _invalidarListas(escopo);
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
