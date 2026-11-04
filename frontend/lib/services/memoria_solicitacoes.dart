import 'dart:async';

import '../models/solicitacao_enviada.dart';
import '../models/solicitacao_recebida.dart';

typedef EscopoSolicitacoes = (int idUsuario, int geracaoSessao);
typedef ConsultarSolicitacoes = Future<Map<String, dynamic>> Function();

class ListasSolicitacoes {
  final List<SolicitacaoRecebida> recebidas;
  final List<SolicitacaoEnviada> enviadas;

  ListasSolicitacoes({
    required Iterable<SolicitacaoRecebida> recebidas,
    required Iterable<SolicitacaoEnviada> enviadas,
  }) : recebidas = List.unmodifiable(recebidas),
       enviadas = List.unmodifiable(enviadas);
}

/// Mantem as duas listas da sessao como um unico resultado validado.
class MemoriaSolicitacoes {
  static final compartilhada = MemoriaSolicitacoes();

  EscopoSolicitacoes? _escopo;
  ListasSolicitacoes? _dados;
  Future<Map<String, dynamic>>? _consulta;
  int _geracao = 0;
  int _revisao = 0;
  int? _revisaoConfirmada;

  void limpar() {
    _geracao++;
    _revisao++;
    _revisaoConfirmada = null;
    _escopo = null;
    _dados = null;
    _consulta = null;
  }

  void _preparar(EscopoSolicitacoes escopo) {
    if (_escopo == escopo) return;
    limpar();
    _escopo = escopo;
  }

  ListasSolicitacoes? ler(EscopoSolicitacoes escopo) {
    _preparar(escopo);
    return _dados;
  }

  bool confirmada(EscopoSolicitacoes escopo) =>
      _escopo == escopo && _dados != null && _revisaoConfirmada == _revisao;

  void invalidar(EscopoSolicitacoes escopo) {
    _preparar(escopo);
    _revisao++;
  }

  Future<Map<String, dynamic>> atualizar(
    EscopoSolicitacoes escopo, {
    required ConsultarSolicitacoes recebidas,
    required ConsultarSolicitacoes enviadas,
  }) {
    _preparar(escopo);
    if (_consulta != null) return _consulta!;
    // Uma leitura anterior nao confirma que os botoes ainda sao aplicaveis.
    _revisaoConfirmada = null;
    final conclusao = Completer<Map<String, dynamic>>();
    _consulta = conclusao.future;
    unawaited(_executar(_geracao, recebidas, enviadas, conclusao));
    return conclusao.future;
  }

  Future<void> _executar(
    int geracao,
    ConsultarSolicitacoes recebidas,
    ConsultarSolicitacoes enviadas,
    Completer<Map<String, dynamic>> conclusao,
  ) async {
    try {
      while (true) {
        final revisao = _revisao;
        Map<String, dynamic> resultado;
        try {
          final respostas = await Future.wait([
            Future.sync(recebidas),
            Future.sync(enviadas),
          ]).timeout(const Duration(seconds: 25));
          final falhas = respostas.where((item) => item['sucesso'] != true);
          if (falhas.isNotEmpty) {
            resultado = {
              'sucesso': false,
              'mensagem':
                  falhas.first['mensagem'] ??
                  'Nao foi possivel atualizar suas solicitacoes.',
            };
          } else {
            final listaRecebidas = respostas[0]['dados'];
            final listaEnviadas = respostas[1]['dados'];
            if (listaRecebidas is! List<SolicitacaoRecebida> ||
                listaEnviadas is! List<SolicitacaoEnviada>) {
              throw const FormatException('Listas de solicitacoes invalidas');
            }
            resultado = {
              'sucesso': true,
              'dados': ListasSolicitacoes(
                recebidas: listaRecebidas,
                enviadas: listaEnviadas,
              ),
            };
          }
        } catch (_) {
          resultado = {
            'sucesso': false,
            'mensagem':
                'Nao foi possivel atualizar suas solicitacoes. Tente novamente.',
          };
        }
        if (geracao != _geracao) {
          conclusao.complete({
            'sucesso': false,
            'codigo': 'CONSULTA_DESCARTADA',
          });
          return;
        }
        // Uma alteracao durante a leitura exige outra consulta posterior a ela.
        if (revisao != _revisao) continue;
        if (resultado['sucesso'] == true) {
          _dados = resultado['dados'] as ListasSolicitacoes;
          _revisaoConfirmada = revisao;
        }
        conclusao.complete(resultado);
        return;
      }
    } finally {
      if (geracao == _geracao) _consulta = null;
    }
  }
}
