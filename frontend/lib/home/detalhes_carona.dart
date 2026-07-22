import 'package:flutter/material.dart';

import '../config/app_colors.dart';
import '../mapa/models/localizacao_selecionada.dart';
import '../mapa/screens/mapa_screen.dart';
import '../models/carona.dart';
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

  const DetalhesCaronaTela({super.key, required this.carona});

  @override
  State<DetalhesCaronaTela> createState() => _DetalhesCaronaTelaState();
}

class _DetalhesCaronaTelaState extends State<DetalhesCaronaTela> {
  bool enviandoSolicitacao = false;
  bool solicitacaoEnviada = false;
  bool excluindoCarona = false;

  bool get usuarioEhMotorista {
    final idRecebido = AuthService.usuarioLogado?['id'];
    final idUsuario = idRecebido is int
        ? idRecebido
        : int.tryParse(idRecebido?.toString() ?? '');

    return idUsuario != null && idUsuario == widget.carona.idMotorista;
  }

  int get indiceNavegacao => usuarioEhMotorista ? 2 : 0;

  Future<void> solicitarVaga() async {
    final localEmbarque = await Navigator.push<LocalizacaoSelecionada>(
      context,
      MaterialPageRoute(
        builder: (context) => const TesteMapa(
          titulo: 'Local de embarque',
          instrucao: 'Confira onde o motorista buscará você',
          textoBotao: 'CONFIRMAR LOCAL DE EMBARQUE',
        ),
      ),
    );

    if (!mounted || localEmbarque == null) {
      return;
    }

    setState(() {
      enviandoSolicitacao = true;
    });

    final resultado = await SolicitacaoService.solicitarVaga(
      idCarona: widget.carona.id,
      localEmbarque: localEmbarque.endereco,
      embarqueLatitude: localEmbarque.ponto.latitude,
      embarqueLongitude: localEmbarque.ponto.longitude,
    );

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
          caronaParaEditar: widget.carona,
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

    final resultado = await CaronaService.excluirCarona(widget.carona.id);

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
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(mensagem)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: BarraSuperiorPadrao(
        titulo: usuarioEhMotorista ? 'Gerenciar carona' : 'Detalhes da carona',
      ),
      body: SafeArea(
        child: ConteudoDetalhesCarona(
          carona: widget.carona,
          rodape: usuarioEhMotorista
              ? PainelSolicitacoesCarona(idCarona: widget.carona.id)
              : null,
        ),
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (usuarioEhMotorista) _acoesGerenciamento() else _botaoSolicitar(),
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
                onPressed: excluindoCarona ? null : confirmarExclusao,
                icon: const Icon(Icons.delete_outline),
                label: const Text('EXCLUIR'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: excluindoCarona ? null : editarCarona,
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
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(
                    solicitacaoEnviada
                        ? Icons.check_circle_outline
                        : Icons.person_add_alt_1,
                  ),
            label: Text(
              solicitacaoEnviada ? 'SOLICITAÇÃO ENVIADA' : 'SOLICITAR VAGA',
            ),
          ),
        ),
      ),
    );
  }
}
