import 'package:flutter/material.dart';

import '../config/app_colors.dart';
import '../mapa/models/localizacao_selecionada.dart';
import '../mapa/widgets/barra_pesquisa_endereco.dart';
import '../navigation/navegacao_principal.dart';
import '../widgets/barra_navegacao_home.dart';
import '../widgets/componentes_padrao.dart';

class SelecionarDestinoTela extends StatefulWidget {
  final LocalizacaoSelecionada? destinoInicial;

  const SelecionarDestinoTela({super.key, this.destinoInicial});

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
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const Text(
              'Para onde você vai?',
              style: TextStyle(
                color: AppColors.text,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Busque pelo nome do lugar ou pelo endereço.',
              style: TextStyle(color: AppColors.text, fontSize: 17),
            ),
            const SizedBox(height: 24),
            BarraPesquisaEndereco(
              label: 'Destino',
              icone: Icons.location_on_outlined,
              controller: destinoController,
              onSelecionado: selecionarDestino,
              padding: EdgeInsets.zero,
              elevacao: 0,
              borderRadius: 16,
              usarLabelComoHint: false,
            ),
          ],
        ),
      ),
    );
  }
}
