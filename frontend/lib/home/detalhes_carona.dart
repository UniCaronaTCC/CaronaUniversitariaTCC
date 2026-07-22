import 'package:flutter/material.dart';

import '../config/app_colors.dart';
import '../mapa/models/localizacao_selecionada.dart';
import '../mapa/screens/mapa_screen.dart';
import '../models/carona.dart';
import '../services/solicitacao_service.dart';
import '../services/auth_service.dart';
import '../widgets/componentes_padrao.dart';
import '../widgets/conteudo_detalhes_carona.dart';

class DetalhesCaronaTela extends StatefulWidget {
  final Carona carona;

  const DetalhesCaronaTela({super.key, required this.carona});

  @override
  State<DetalhesCaronaTela> createState() => _DetalhesCaronaTelaState();
}

class _DetalhesCaronaTelaState extends State<DetalhesCaronaTela> {
  bool enviandoSolicitacao = false;
  bool solicitacaoEnviada = false;

  bool get usuarioEhMotorista {
    final idRecebido = AuthService.usuarioLogado?['id'];
    final idUsuario = idRecebido is int
        ? idRecebido
        : int.tryParse(idRecebido?.toString() ?? '');

    return idUsuario != null && idUsuario == widget.carona.idMotorista;
  }

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

    final mensagem =
        resultado['mensagem']?.toString() ?? 'Erro ao solicitar vaga';

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(mensagem)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const BarraSuperiorPadrao(titulo: 'Detalhes da carona'),
      body: SafeArea(child: ConteudoDetalhesCarona(carona: widget.carona)),
      bottomNavigationBar: usuarioEhMotorista
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
                child: SizedBox(
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
                      solicitacaoEnviada
                          ? 'SOLICITAÇÃO ENVIADA'
                          : 'SOLICITAR VAGA',
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}
