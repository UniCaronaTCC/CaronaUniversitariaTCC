import 'package:flutter/material.dart';

import '../config/app_colors.dart';
import '../mapa/models/localizacao_selecionada.dart';
import '../mapa/services/endereco_service.dart';
import '../navigation/navegacao_principal.dart';
import '../services/campus_destino_service.dart';
import '../widgets/barra_navegacao_home.dart';
import '../widgets/componentes_padrao.dart';
import '../widgets/campo_destino_campus.dart';

class SelecionarDestinoTela extends StatefulWidget {
  final LocalizacaoSelecionada? destinoInicial;
  final LocalizacaoSelecionada? localizacaoReferencia;
  final CampusDestinoService campusService;
  final EnderecoService? enderecoService;

  const SelecionarDestinoTela({
    super.key,
    this.destinoInicial,
    this.localizacaoReferencia,
    this.campusService = const CampusDestinoService(),
    this.enderecoService,
  });

  @override
  State<SelecionarDestinoTela> createState() => _SelecionarDestinoTelaState();
}

class _SelecionarDestinoTelaState extends State<SelecionarDestinoTela> {
  final TextEditingController destinoController = TextEditingController();

  @override
  void initState() {
    super.initState();
    destinoController.text = widget.destinoInicial?.descricaoCompleta ?? '';
  }

  void selecionarDestino(LocalizacaoSelecionada destino) {
    Navigator.pop(context, destino);
  }

  @override
  void dispose() {
    destinoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const BarraSuperiorPadrao(titulo: 'Escolher destino'),
      bottomNavigationBar: BarraNavegacaoHome(
        onTap: (indice) =>
            NavegacaoPrincipal.selecionar(context, indice, indiceAtual: 0),
      ),
      body: SafeArea(
        child: CampoDestinoCampus(
          controller: destinoController,
          onSelecionado: selecionarDestino,
          referenciaInicial:
              widget.localizacaoReferencia ?? widget.destinoInicial,
          mostrarAoAbrir: true,
          telaCompleta: true,
          campusService: widget.campusService,
          enderecoService: widget.enderecoService,
        ),
      ),
    );
  }
}
