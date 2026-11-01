import 'package:flutter/material.dart';

import '../config/app_colors.dart';
import '../models/carona.dart';
import '../services/carona_service.dart';
import '../widgets/card_carona_publicada.dart';
import '../widgets/componentes_padrao.dart';
import '../widgets/visual_buscaeu.dart';
import 'detalhes_carona.dart';
import 'recorrencias.dart';
import 'ofertar_carona.dart';

class CaronasPublicadasTela extends StatefulWidget {
  final Future<Map<String, dynamic>> Function()? carregarPublicadas;
  const CaronasPublicadasTela({super.key, this.carregarPublicadas});

  @override
  State<CaronasPublicadasTela> createState() => _CaronasPublicadasTelaState();
}

class _CaronasPublicadasTelaState extends State<CaronasPublicadasTela> {
  List<Carona> caronas = [];
  bool carregando = true;
  bool abrindoOferta = false;
  String? mensagemErro;

  @override
  void initState() {
    super.initState();
    carregarCaronas();
  }

  Future<void> carregarCaronas() async {
    setState(() {
      carregando = true;
      mensagemErro = null;
    });

    final resultado =
        await (widget.carregarPublicadas?.call() ??
            CaronaService.listarMinhasCaronas());

    if (!mounted) {
      return;
    }

    final dados = resultado['dados'];

    setState(() {
      carregando = false;

      if (resultado['sucesso'] == true && dados is List<Carona>) {
        caronas = dados.where((carona) => !carona.encerrada).toList()
          ..sort((a, b) {
            final data = a.dataInicio.compareTo(b.dataInicio);
            return data != 0 ? data : a.horario.compareTo(b.horario);
          });
      } else {
        mensagemErro =
            resultado['mensagem']?.toString() ?? 'Erro ao carregar caronas';
      }
    });
  }

  Future<void> abrirDetalhes(Carona carona) async {
    final alterada = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            DetalhesCaronaTela(carona: carona, indiceNavegacaoOrigem: 0),
      ),
    );

    if (alterada == true) {
      await carregarCaronas();
    }
  }

  Future<void> abrirOferta() async {
    if (abrindoOferta) return;
    setState(() => abrindoOferta = true);
    try {
      final publicada = await Navigator.push<bool>(
        context,
        MaterialPageRoute(builder: (_) => const OfertarCaronaTela()),
      );
      if (mounted && publicada == true) await carregarCaronas();
    } finally {
      if (mounted) setState(() => abrindoOferta = false);
    }
  }

  Future<void> abrirRecorrencias() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const RecorrenciasTela()),
    );
    if (mounted) await carregarCaronas();
  }

  @override
  Widget build(BuildContext context) {
    return VisualBuscaEu(
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('Suas caronas'),
          backgroundColor: AppColors.background,
          foregroundColor: AppColors.text,
          elevation: 0,
          actions: [
            if (MediaQuery.sizeOf(context).width < 380 ||
                MediaQuery.textScalerOf(context).scale(14) > 18)
              IconButton(
                tooltip: 'Recorrências',
                icon: const Icon(Icons.repeat),
                onPressed: abrirRecorrencias,
              )
            else
              TextButton.icon(
                icon: const Icon(Icons.repeat),
                label: const Text('Recorrências'),
                onPressed: abrirRecorrencias,
              ),
          ],
        ),
        body: SafeArea(
          child: RefreshIndicator(
            onRefresh: carregarCaronas,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(24),
              children: [
                const Text(
                  'Gerencie suas viagens',
                  style: VisualBuscaEu.descricao,
                ),
                const SizedBox(height: 16),
                if (carregando)
                  const EstadoConteudoPadrao(
                    carregando: true,
                    mensagem: 'Carregando suas caronas...',
                  )
                else if (mensagemErro != null)
                  EstadoConteudoPadrao(
                    icone: Icons.cloud_off_outlined,
                    mensagem: mensagemErro!,
                    textoBotao: 'Tentar novamente',
                    onPressed: carregarCaronas,
                  )
                else if (caronas.isEmpty)
                  const EstadoConteudoPadrao(
                    icone: Icons.directions_car_outlined,
                    mensagem: 'Você não possui caronas ativas',
                  )
                else
                  ListView.separated(
                    itemCount: caronas.length,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (_, index) {
                      final carona = caronas[index];

                      return CardCaronaPublicada(
                        carona: carona,
                        onTap: () => abrirDetalhes(carona),
                      );
                    },
                  ),
              ],
            ),
          ),
        ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
            child: ElevatedButton.icon(
              onPressed: abrindoOferta ? null : abrirOferta,
              icon: const Icon(Icons.add),
              label: const Text('Ofertar carona'),
            ),
          ),
        ),
      ),
    );
  }
}
