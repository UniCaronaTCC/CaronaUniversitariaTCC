import 'dart:async';

typedef EscopoResumoPerfil = (int idUsuario, int geracaoSessao);
typedef ConsultarResumoPerfil = Future<Map<String, dynamic>> Function();

class ResumoAvaliacoesPerfil {
  final double media;
  final int total;

  const ResumoAvaliacoesPerfil._(this.media, this.total);

  factory ResumoAvaliacoesPerfil.fromJson(Map<String, dynamic> dados) {
    final media = double.tryParse(dados['media']?.toString() ?? '');
    final total = int.tryParse(dados['total']?.toString() ?? '');
    if (media == null ||
        !media.isFinite ||
        media < 0 ||
        media > 5 ||
        total == null ||
        total < 0) {
      throw const FormatException('Resumo de avaliacoes invalido');
    }
    return ResumoAvaliacoesPerfil._(media, total);
  }
}

/// Guarda somente media e quantidade da conta atual, nunca o perfil completo.
class MemoriaResumoPerfil {
  static final compartilhada = MemoriaResumoPerfil();

  EscopoResumoPerfil? _escopo;
  ResumoAvaliacoesPerfil? _dados;
  Future<Map<String, dynamic>>? _consulta;
  int _geracao = 0;
  int _revisao = 0;
  String? _erroAtualizacao;

  bool get consultando => _consulta != null;
  String? get erroAtualizacao => _erroAtualizacao;

  void limpar() {
    _geracao++;
    _revisao++;
    _escopo = null;
    _dados = null;
    _consulta = null;
    _erroAtualizacao = null;
  }

  void _preparar(EscopoResumoPerfil escopo) {
    if (_escopo == escopo) return;
    limpar();
    _escopo = escopo;
  }

  ResumoAvaliacoesPerfil? ler(EscopoResumoPerfil escopo) {
    _preparar(escopo);
    return _dados;
  }

  void invalidar(EscopoResumoPerfil escopo) {
    _preparar(escopo);
    _revisao++;
  }

  Future<Map<String, dynamic>> atualizar(
    EscopoResumoPerfil escopo,
    ConsultarResumoPerfil consultar,
  ) {
    _preparar(escopo);
    if (_consulta != null) return _consulta!;
    _erroAtualizacao = null;
    final conclusao = Completer<Map<String, dynamic>>();
    _consulta = conclusao.future;
    unawaited(_executar(_geracao, consultar, conclusao));
    return conclusao.future;
  }

  Future<void> _executar(
    int geracao,
    ConsultarResumoPerfil consultar,
    Completer<Map<String, dynamic>> conclusao,
  ) async {
    try {
      while (true) {
        final revisao = _revisao;
        Map<String, dynamic> resultado;
        try {
          final resposta = await Future.sync(
            consultar,
          ).timeout(const Duration(seconds: 25));
          if (resposta['sucesso'] != true) {
            resultado = {
              'sucesso': false,
              'mensagem':
                  resposta['mensagem']?.toString() ??
                  'Nao foi possivel atualizar suas avaliacoes.',
            };
          } else {
            final dados = resposta['dados'];
            if (dados is! Map<String, dynamic>) {
              throw const FormatException('Resumo de avaliacoes invalido');
            }
            resultado = {
              'sucesso': true,
              'dados': ResumoAvaliacoesPerfil.fromJson(dados),
            };
          }
        } catch (_) {
          resultado = {
            'sucesso': false,
            'mensagem':
                'Nao foi possivel atualizar suas avaliacoes. Tente novamente.',
          };
        }
        if (geracao != _geracao) {
          conclusao.complete({
            'sucesso': false,
            'codigo': 'CONSULTA_DESCARTADA',
          });
          return;
        }
        // Uma invalidacao exige uma resposta posterior, nao apenas a que ja vinha chegando.
        if (revisao != _revisao) continue;
        if (resultado['sucesso'] == true) {
          _dados = resultado['dados'] as ResumoAvaliacoesPerfil;
          _erroAtualizacao = null;
        } else {
          _erroAtualizacao = resultado['mensagem']?.toString();
        }
        conclusao.complete(resultado);
        return;
      }
    } finally {
      if (geracao == _geracao) _consulta = null;
    }
  }
}
