import 'package:flutter/material.dart';

import '../config/app_colors.dart';
import '../mapa/models/localizacao_selecionada.dart';
import '../mapa/services/endereco_service.dart';
import '../widgets/campo_texto_carona.dart';
import '../widgets/componentes_padrao.dart';

class SelecionarDestinoTela extends StatefulWidget {
  final LocalizacaoSelecionada? destinoInicial;

  const SelecionarDestinoTela({super.key, this.destinoInicial});

  @override
  State<SelecionarDestinoTela> createState() => _SelecionarDestinoTelaState();
}

class _SelecionarDestinoTelaState extends State<SelecionarDestinoTela> {
  final TextEditingController destinoController = TextEditingController();
  final EnderecoService enderecoService = EnderecoService();

  List<LocalizacaoSelecionada> opcoes = [];
  bool buscando = false;
  bool buscaRealizada = false;

  @override
  void initState() {
    super.initState();
    destinoController.text = widget.destinoInicial?.descricaoCompleta ?? '';
  }

  Future<void> buscarDestino() async {
    final textoBusca = destinoController.text.trim();

    if (textoBusca.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Digite um destino')));
      return;
    }

    FocusScope.of(context).unfocus();

    setState(() {
      buscando = true;
      buscaRealizada = false;
      opcoes = [];
    });

    final resultados = await enderecoService.buscarLocalizacoesPorEndereco(
      textoBusca,
    );

    if (!mounted) {
      return;
    }

    // Ignora uma resposta antiga se o texto mudou durante a busca.
    if (destinoController.text.trim() != textoBusca) {
      setState(() {
        buscando = false;
      });
      return;
    }

    setState(() {
      buscando = false;
      buscaRealizada = true;
      opcoes = resultados;
    });
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
            CampoTextoCarona(
              label: 'Destino',
              icone: Icons.location_on_outlined,
              controller: destinoController,
              keyboardType: TextInputType.streetAddress,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => buscarDestino(),
              suffixIcon: buscando
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : IconButton(
                      tooltip: 'Buscar destino',
                      onPressed: buscarDestino,
                      icon: const Icon(Icons.search),
                    ),
            ),
            const SizedBox(height: 24),
            if (buscando)
              const EstadoConteudoPadrao(
                carregando: true,
                mensagem: 'Buscando endereços...',
              )
            else if (buscaRealizada && opcoes.isEmpty)
              const EstadoConteudoPadrao(
                icone: Icons.location_off_outlined,
                mensagem: 'Nenhum destino encontrado',
              )
            else if (opcoes.isNotEmpty) ...[
              const Text(
                'Selecione uma opção',
                style: TextStyle(
                  color: AppColors.text,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              ...opcoes.map(
                (opcao) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(
                    Icons.location_on_outlined,
                    color: AppColors.primary,
                  ),
                  title: Text(opcao.endereco),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => selecionarDestino(opcao),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
