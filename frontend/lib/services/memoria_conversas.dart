import 'dart:async';

import '../models/conversa.dart';

typedef EscopoConversas = (int idUsuario, int geracaoSessao);
typedef ConsultarListaConversas = Future<Map<String, dynamic>> Function();

/// Guarda somente a ultima lista valida da sessao, nunca o historico completo.
class MemoriaConversas {
  static final compartilhada = MemoriaConversas();

  EscopoConversas? _escopo;
  List<Conversa>? _dados;
  Future<Map<String, dynamic>>? _consulta;
  int _geracao = 0;
  int _revisao = 0;

  void limpar() {
    _geracao++;
    _revisao++;
    _escopo = null;
    _dados = null;
    _consulta = null;
  }

  void _preparar(EscopoConversas escopo) {
    if (_escopo == escopo) return;
    limpar();
    _escopo = escopo;
  }

  List<Conversa>? ler(EscopoConversas escopo) {
    _preparar(escopo);
    return _dados;
  }

  void invalidar(EscopoConversas escopo) {
    _preparar(escopo);
    _revisao++;
  }

  Future<Map<String, dynamic>> atualizar(
    EscopoConversas escopo,
    ConsultarListaConversas consultar,
  ) {
    _preparar(escopo);
    if (_consulta != null) return _consulta!;
    final conclusao = Completer<Map<String, dynamic>>();
    _consulta = conclusao.future;
    unawaited(_executar(_geracao, consultar, conclusao));
    return conclusao.future;
  }

  Future<void> _executar(
    int geracao,
    ConsultarListaConversas consultar,
    Completer<Map<String, dynamic>> conclusao,
  ) async {
    try {
      while (true) {
        final revisao = _revisao;
        Map<String, dynamic> resultado;
        try {
          resultado = await consultar().timeout(const Duration(seconds: 25));
        } catch (_) {
          resultado = {
            'sucesso': false,
            'mensagem':
                'Não foi possível atualizar as conversas. Tente novamente.',
          };
        }
        if (geracao != _geracao) {
          conclusao.complete({
            'sucesso': false,
            'codigo': 'CONSULTA_DESCARTADA',
          });
          return;
        }
        // Um evento ou retorno do chat exige uma consulta posterior a ele.
        if (revisao != _revisao) continue;
        final dados = resultado['dados'];
        if (resultado['sucesso'] == true) {
          if (dados is! List || dados.any((item) => item is! Conversa)) {
            resultado = {
              'sucesso': false,
              'mensagem':
                  'O servidor retornou uma lista de conversas inválida.',
            };
          } else {
            _dados = List<Conversa>.unmodifiable(dados.cast<Conversa>());
            resultado = {...resultado, 'dados': _dados};
          }
        }
        conclusao.complete(resultado);
        return;
      }
    } finally {
      if (geracao == _geracao) _consulta = null;
    }
  }
}
