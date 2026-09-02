import 'package:flutter/material.dart';

import '../config/app_colors.dart';
import '../mapa/models/localizacao_selecionada.dart';
import '../mapa/screens/mapa_screen.dart';
import '../models/carona.dart';
import '../models/ponto_embarque.dart';
import '../navigation/navegacao_principal.dart';
import '../services/auth_service.dart';
import '../services/carona_service.dart';
import '../services/solicitacao_service.dart';
import '../widgets/barra_navegacao_home.dart';
import '../widgets/componentes_padrao.dart';
import '../widgets/conteudo_detalhes_carona.dart';
import '../widgets/painel_solicitacoes_carona.dart';
import 'ofertar_carona.dart';

class DetalhesCaronaTela extends StatefulWidget {
  final Carona carona;

  const DetalhesCaronaTela({
    super.key,
    required this.carona,
  });

  @override
  State<DetalhesCaronaTela> createState() => _DetalhesCaronaTelaState();
}

class _DetalhesCaronaTelaState extends State<DetalhesCaronaTela> {
  Carona? _caronaAtualizada;
  int _ultimaAtualizacao = 0;

  Carona get caronaAtual => _caronaAtualizada ?? widget.carona;

  Future<void> _atualizarCarona() async {
    final atualizacao = ++_ultimaAtualizacao;
    final idCarona = caronaAtual.id;
    try {
      final resultado = await CaronaService.listarMinhasCaronas()
          .timeout(const Duration(seconds: 20));
      if (!mounted || atualizacao != _ultimaAtualizacao) return;

      final dados = resultado['dados'];
      if (resultado['sucesso'] == true && dados is List<Carona>) {
        for (final carona in dados) {
          if (carona.id == idCarona) {
            setState(() => _caronaAtualizada = carona);
            return;
          }
        }
      }
    } catch (_) {
      if (!mounted || atualizacao != _ultimaAtualizacao) return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text(
          'A solicitação foi aceita, mas não foi possível atualizar o percurso.',
        ),
        action: SnackBarAction(
          label: 'ATUALIZAR',
          onPressed: _atualizarCarona,
        ),
      ),
    );
  }

  bool enviandoSolicitacao = false;
  bool solicitacaoEnviada = false;
  bool excluindoCarona = false;

  bool get usuarioEhMotorista {
    final idRecebido = AuthService.usuarioLogado?['id'];

    final idUsuario = idRecebido is int
        ? idRecebido
        : int.tryParse(idRecebido?.toString() ?? '');

    return idUsuario != null && idUsuario == caronaAtual.idMotorista;
  }

  int get indiceNavegacao => usuarioEhMotorista ? 2 : 0;

  Future<void> solicitarVaga() async {
    final escolha = await _selecionarPontoEmbarque();

    if (!mounted || escolha == null) {
      return;
    }

    if (escolha == 'NOVO') {
      await _solicitarNovoPonto();
      return;
    }

    final ponto = escolha as PontoEmbarque;

    if (ponto.id == null) {
      _mostrarMensagem('Ponto de embarque inválido');
      return;
    }

    await _enviarSolicitacao(
      SolicitacaoService.solicitarVagaComPontoExistente(
        idCarona: caronaAtual.id,
        idPontoEmbarque: ponto.id!,
      ),
    );
  }

  Future<Object?> _selecionarPontoEmbarque() {
    return showModalBottomSheet<Object>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
            children: [
              const Text(
                'Escolha o ponto de embarque',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Selecione um dos pontos cadastrados pelo motorista.',
              ),
              const SizedBox(height: 16),

              if (caronaAtual.pontosEmbarque.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    'Nenhum ponto de embarque foi cadastrado.',
                  ),
                )
              else
                ...caronaAtual.pontosEmbarque.map(_itemPontoEmbarque),

              const Divider(height: 28),

              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(
                  Icons.add_location_alt_outlined,
                ),
                title: const Text(
                  'Solicitar novo ponto de embarque',
                ),
                subtitle: const Text(
                  'O motorista poderá aceitar ou recusar o novo local.',
                ),
                onTap: () => Navigator.pop(context, 'NOVO'),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _itemPontoEmbarque(PontoEmbarque ponto) {
    final nome = ponto.nome?.trim();

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.location_on_outlined),
      title: Text(
        nome != null && nome.isNotEmpty
            ? nome
            : 'Ponto de embarque',
      ),
      subtitle: Text(ponto.endereco),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => Navigator.pop(context, ponto),
    );
  }

  Future<void> _solicitarNovoPonto() async {
    final localEmbarque = await Navigator.push<LocalizacaoSelecionada>(
      context,
      MaterialPageRoute(
        builder: (context) => const TesteMapa(
          titulo: 'Novo ponto de embarque',
          instrucao: 'Escolha o ponto que deseja solicitar ao motorista',
          textoBotao: 'SOLICITAR ESTE PONTO',
        ),
      ),
    );

    if (!mounted || localEmbarque == null) {
      return;
    }

    await _enviarSolicitacao(
      SolicitacaoService.solicitarVagaComNovoPonto(
        idCarona: caronaAtual.id,
        localEmbarque: localEmbarque.endereco,
        embarqueLatitude: localEmbarque.ponto.latitude,
        embarqueLongitude: localEmbarque.ponto.longitude,
      ),
    );
  }

  Future<void> _enviarSolicitacao(
      Future<Map<String, dynamic>> requisicao,
      ) async {
    setState(() {
      enviandoSolicitacao = true;
    });

    final resultado = await requisicao;

    if (!mounted) {
      return;
    }

    setState(() {
      enviandoSolicitacao = false;
      solicitacaoEnviada = resultado['sucesso'] == true;
    });

    _mostrarMensagem(
      resultado['mensagem']?.toString() ?? 'Erro ao solicitar vaga',
    );
  }

  Future<void> editarCarona() async {
    final alterada = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => OfertarCaronaTela(
          caronaParaEditar: caronaAtual,
          indiceNavegacao: 2,
        ),
      ),
    );

    if (mounted && alterada == true) {
      Navigator.pop(context, true);
    }
  }

  Future<void> confirmarExclusao() async {
    final confirmou = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir carona?'),
        content: const Text(
          'A oferta deixará de aparecer para os passageiros.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('CANCELAR'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('EXCLUIR'),
          ),
        ],
      ),
    );

    if (confirmou != true || !mounted) {
      return;
    }

    setState(() {
      excluindoCarona = true;
    });

    final resultado = await CaronaService.excluirCarona(
      caronaAtual.id,
    );

    if (!mounted) {
      return;
    }

    setState(() {
      excluindoCarona = false;
    });

    _mostrarMensagem(
      resultado['mensagem']?.toString() ?? 'Erro ao excluir carona',
    );

    if (resultado['sucesso'] == true) {
      Navigator.pop(context, true);
    }
  }

  void _mostrarMensagem(String mensagem) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensagem),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: BarraSuperiorPadrao(
        titulo: usuarioEhMotorista
            ? 'Gerenciar carona'
            : 'Detalhes da carona',
      ),
      body: SafeArea(
        child: ConteudoDetalhesCarona(
          carona: caronaAtual,
          rodape: usuarioEhMotorista
              ? PainelSolicitacoesCarona(
            idCarona: caronaAtual.id,
            onSolicitacaoAceita: _atualizarCarona,
          )
              : null,
        ),
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (usuarioEhMotorista && !caronaAtual.finalizada)
            _acoesGerenciamento()
          else if (!usuarioEhMotorista && !caronaAtual.finalizada)
            _botaoSolicitar(),

          BarraNavegacaoHome(
            currentIndex: indiceNavegacao,
            onTap: (indice) => NavegacaoPrincipal.selecionar(
              context,
              indice,
              indiceAtual: indiceNavegacao,
            ),
          ),
        ],
      ),
    );
  }

  Widget _acoesGerenciamento() {
    return SafeArea(
      top: false,
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 10, 24, 10),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: excluindoCarona
                    ? null
                    : confirmarExclusao,
                icon: const Icon(Icons.delete_outline),
                label: const Text('EXCLUIR'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: excluindoCarona
                    ? null
                    : editarCarona,
                icon: const Icon(Icons.edit_outlined),
                label: const Text('EDITAR'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _botaoSolicitar() {
    return SafeArea(
      top: false,
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 10, 24, 10),
        child: SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton.icon(
            onPressed: enviandoSolicitacao || solicitacaoEnviada
                ? null
                : solicitarVaga,
            icon: enviandoSolicitacao
                ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
              ),
            )
                : Icon(
              solicitacaoEnviada
                  ? Icons.check_circle_outline
                  : Icons.person_add_alt_1,
            ),
            label: Text(
              solicitacaoEnviada
                  ? 'SOLICITAÇÃO ENVIADA'
                  : 'SOLICITAR VAGA',
            ),

          ),
        ),
      ),
    );
  }
}
