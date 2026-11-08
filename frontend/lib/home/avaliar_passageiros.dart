import 'package:flutter/material.dart';

import '../config/app_colors.dart';
import '../models/solicitacao_recebida.dart';
import '../services/auth_service.dart';
import '../services/avaliacao_service.dart';
import '../services/solicitacao_service.dart';
import '../widgets/aviso_app.dart';
import '../widgets/card_solicitacao_recebida.dart';
import '../widgets/componentes_padrao.dart';
import '../widgets/dialogo_avaliacao.dart';
import '../widgets/visual_buscaeu.dart';

typedef CarregarPassageirosAvaliacao =
    Future<Map<String, dynamic>> Function(int idCarona);
typedef EnviarAvaliacaoPassageiro =
    Future<Map<String, dynamic>> Function({
      required int idSolicitacao,
      required int nota,
      String? comentario,
    });

class AvaliarPassageirosTela extends StatefulWidget {
  final int idCarona;
  final CarregarPassageirosAvaliacao? carregarPassageiros;
  final EnviarAvaliacaoPassageiro? enviarAvaliacao;

  const AvaliarPassageirosTela({
    super.key,
    required this.idCarona,
    this.carregarPassageiros,
    this.enviarAvaliacao,
  });

  @override
  State<AvaliarPassageirosTela> createState() => _AvaliarPassageirosTelaState();
}

class _AvaliarPassageirosTelaState extends State<AvaliarPassageirosTela> {
  List<SolicitacaoRecebida> passageiros = [];
  final _avaliadasNestaTela = <int>{};
  late final int _versaoSessao;
  bool carregando = true;
  bool _consultando = false;
  bool _dialogoAberto = false;
  int? idProcessando;
  String? mensagemErro;

  bool get _sessaoValida => _versaoSessao == AuthService.versaoSessao;
  bool get _ocupada => carregando || _dialogoAberto || idProcessando != null;
  bool _avaliada(SolicitacaoRecebida item) =>
      item.avaliada || _avaliadasNestaTela.contains(item.id);

  @override
  void initState() {
    super.initState();
    _versaoSessao = AuthService.versaoSessao;
    AuthService.alteracoesSessao.addListener(_aoMudarSessao);
    carregarDados();
  }

  @override
  void dispose() {
    AuthService.alteracoesSessao.removeListener(_aoMudarSessao);
    super.dispose();
  }

  void _aoMudarSessao() {
    if (!mounted) {
      return;
    }
    setState(() {
      passageiros = [];
      _avaliadasNestaTela.clear();
      carregando = false;
      mensagemErro = 'Sua sessão mudou. Abra o histórico novamente.';
    });
  }

  Future<void> carregarDados() async {
    if (_consultando ||
        _dialogoAberto ||
        idProcessando != null ||
        !_sessaoValida) {
      return;
    }
    _consultando = true;
    setState(() {
      carregando = true;
      mensagemErro = null;
    });
    Map<String, dynamic> resultado;
    try {
      resultado =
          await (widget.carregarPassageiros?.call(widget.idCarona) ??
              SolicitacaoService.listarRecebidas(idCarona: widget.idCarona));
    } catch (_) {
      resultado = {
        'sucesso': false,
        'mensagem': 'Erro ao carregar passageiros',
      };
    } finally {
      _consultando = false;
    }
    if (!mounted || !_sessaoValida) {
      return;
    }
    final dados = resultado['dados'];
    setState(() {
      carregando = false;
      if (resultado['sucesso'] != true || dados is! List<SolicitacaoRecebida>) {
        mensagemErro =
            resultado['mensagem']?.toString() ?? 'Erro ao carregar passageiros';
        return;
      }
      passageiros = dados
          .where(
            (item) =>
                item.idCarona == widget.idCarona &&
                item.status == 'ACEITA' &&
                item.caronaFinalizada &&
                (item.podeAvaliar || _avaliada(item)),
          )
          .toList();
    });
  }

  Future<void> avaliar(SolicitacaoRecebida passageiro) async {
    if (_ocupada ||
        !_sessaoValida ||
        _avaliada(passageiro) ||
        !passageiro.podeAvaliar ||
        passageiro.status != 'ACEITA' ||
        !passageiro.caronaFinalizada) {
      return;
    }
    setState(() => _dialogoAberto = true);
    final dados = await mostrarDialogoAvaliacao(context, passageiro.passageiro);
    if (!mounted) {
      return;
    }
    setState(() => _dialogoAberto = false);
    if (dados == null ||
        !_sessaoValida ||
        ModalRoute.of(context)?.isCurrent != true) {
      return;
    }
    setState(() => idProcessando = passageiro.id);
    Map<String, dynamic> resultado;
    try {
      resultado = await (widget.enviarAvaliacao ?? AvaliacaoService.enviar)(
        idSolicitacao: passageiro.id,
        nota: dados.nota,
        comentario: dados.comentario,
      );
    } catch (_) {
      resultado = {'sucesso': false, 'mensagem': 'Erro ao enviar avaliação'};
    }
    if (!mounted || !_sessaoValida) {
      return;
    }
    final sucesso = resultado['sucesso'] == true;
    setState(() {
      idProcessando = null;
      if (sucesso) {
        _avaliadasNestaTela.add(passageiro.id);
      }
    });
    if (ModalRoute.of(context)?.isCurrent == true) {
      AvisoApp.mostrar(
        context,
        resultado['mensagem']?.toString() ??
            (sucesso ? 'Avaliação enviada' : 'Erro ao enviar avaliação'),
        tipo: sucesso ? TipoAviso.sucesso : TipoAviso.erro,
      );
    }
    if (sucesso) {
      await carregarDados();
    }
  }

  @override
  Widget build(BuildContext context) => VisualBuscaEu(
    child: Scaffold(
      backgroundColor: AppColors.background,
      appBar: const BarraSuperiorPadrao(titulo: 'Avaliar passageiros'),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: carregarDados,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(24),
            children: [
              if (carregando)
                const EstadoConteudoPadrao(
                  carregando: true,
                  mensagem: 'Carregando passageiros...',
                )
              else if (mensagemErro != null)
                EstadoConteudoPadrao(
                  icone: Icons.error_outline,
                  mensagem: mensagemErro,
                  textoBotao: _sessaoValida ? 'Tentar novamente' : null,
                  onPressed: _sessaoValida ? carregarDados : null,
                )
              else if (passageiros.isEmpty)
                const EstadoConteudoPadrao(
                  icone: Icons.people_outline,
                  mensagem:
                      'Nenhum passageiro disponível para avaliação nesta carona.',
                )
              else ...[
                const Text(
                  'Avalie os passageiros desta carona finalizada.',
                  style: VisualBuscaEu.descricao,
                ),
                const SizedBox(height: 16),
                for (final passageiro in passageiros) ...[
                  CardSolicitacaoRecebida(
                    solicitacao: passageiro,
                    processando: idProcessando == passageiro.id,
                    acoesHabilitadas: !_ocupada && _sessaoValida,
                    onAceitar: () {},
                    onRecusar: () {},
                    onAvaliar: _avaliada(passageiro)
                        ? null
                        : () => avaliar(passageiro),
                  ),
                  if (_avaliada(passageiro))
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Text(
                        'Avaliação enviada',
                        style: VisualBuscaEu.descricao,
                      ),
                    ),
                  const SizedBox(height: 16),
                ],
              ],
            ],
          ),
        ),
      ),
    ),
  );
}
