import 'package:flutter/material.dart';

import '../config/app_colors.dart';
import '../models/carona.dart';
import '../navigation/navegacao_principal.dart';
import '../services/carona_service.dart';
import '../widgets/barra_navegacao_home.dart';
import '../widgets/card_carona_disponivel.dart';
import '../widgets/componentes_padrao.dart';
import 'detalhes_carona.dart';

class CaronasPublicadasTela extends StatefulWidget {
  const CaronasPublicadasTela({super.key});

  @override
  State<CaronasPublicadasTela> createState() => _CaronasPublicadasTelaState();
}

class _CaronasPublicadasTelaState extends State<CaronasPublicadasTela> {
  List<Carona> caronas = [];
  bool carregando = true;
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

    final resultado = await CaronaService.listarMinhasCaronas();

    if (!mounted) {
      return;
    }

    final dados = resultado['dados'];

    setState(() {
      carregando = false;

      if (resultado['sucesso'] == true && dados is List<Carona>) {
        caronas = dados.where((carona) => !carona.finalizada).toList();
      } else {
        mensagemErro =
            resultado['mensagem']?.toString() ?? 'Erro ao carregar caronas';
      }
    });
  }

  Future<void> abrirDetalhes(Carona carona) async {
    final alterada = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => DetalhesCaronaTela(carona: carona)),
    );

    if (alterada == true) {
      await carregarCaronas();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Caronas publicadas'),
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.text,
        elevation: 0,
      ),
      bottomNavigationBar: BarraNavegacaoHome(
        currentIndex: 2,
        onTap: (indice) =>
            NavegacaoPrincipal.selecionar(context, indice, indiceAtual: 2),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: carregarCaronas,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(24),
            children: [
              const Text(
                'Toque em uma carona para editar ou ver as solicitações.',
                style: TextStyle(color: AppColors.text, fontSize: 15),
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

                    return CardCaronaDisponivel(
                      carona: carona,
                      onTap: () => abrirDetalhes(carona),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}
