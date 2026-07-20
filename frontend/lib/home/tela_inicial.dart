import 'package:flutter/material.dart';

import '../config/app_colors.dart';
import '../models/carona.dart';
import '../services/carona_service.dart';
import '../widgets/barra_navegacao_home.dart';
import '../widgets/botao_acao_home.dart';
import '../widgets/card_carona_disponivel.dart';
import '../widgets/card_destino_home.dart';
import 'buscar_carona.dart';
import 'ofertar_carona.dart';

class TelaInicial extends StatefulWidget {
  final String nomeUsuario;

  const TelaInicial({super.key, required this.nomeUsuario});

  @override
  State<TelaInicial> createState() => _TelaInicialState();
}

class _TelaInicialState extends State<TelaInicial> {
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

    final resultado = await CaronaService.listarCaronas();

    if (!mounted) {
      return;
    }

    if (resultado['sucesso'] == true) {
      final dados = resultado['dados'];

      setState(() {
        caronas = dados is List<Carona> ? dados : [];
        carregando = false;
      });

      return;
    }

    setState(() {
      carregando = false;
      mensagemErro =
          resultado['mensagem']?.toString() ?? 'Erro ao carregar caronas';
    });
  }

  Future<void> abrirBusca() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const BuscarCaronaTela()),
    );

    // Atualiza a Home ao voltar da busca.
    await carregarCaronas();
  }

  Future<void> abrirOferta() async {
    final caronaCriada = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (context) => const OfertarCaronaTela()),
    );

    // Atualiza imediatamente depois de criar uma oferta.
    if (caronaCriada == true) {
      await carregarCaronas();
    }
  }

  void abrirDetalhes(Carona carona) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Detalhes da carona de ${carona.motorista}')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final caronasHome = caronas.take(3).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      bottomNavigationBar: const BarraNavegacaoHome(),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: carregarCaronas,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text.rich(
                  TextSpan(
                    children: [
                      const TextSpan(
                        text: 'Olá, ',
                        style: TextStyle(color: AppColors.text, fontSize: 32),
                      ),
                      TextSpan(
                        text: widget.nomeUsuario.isNotEmpty
                            ? widget.nomeUsuario
                            : 'usuário',
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Para onde você vai hoje?',
                  style: TextStyle(fontSize: 20, color: AppColors.text),
                ),
                const SizedBox(height: 36),

                const CardDestinoHome(
                  destino: 'AVENIDA UNISALESIANO, NÚMERO 2026',
                ),
                const SizedBox(height: 36),

                BotaoAcaoHome(
                  texto: 'BUSCAR',
                  icone: Icons.search,
                  onPressed: abrirBusca,
                ),
                const SizedBox(height: 20),

                BotaoAcaoHome(
                  texto: 'OFERTAR',
                  icone: Icons.add_road,
                  onPressed: abrirOferta,
                ),
                const SizedBox(height: 36),

                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Caronas disponíveis',
                        style: TextStyle(
                          color: AppColors.text,
                          fontSize: 22,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: abrirBusca,
                      child: const Text('Ver todas'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                if (carregando)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: CircularProgressIndicator(),
                    ),
                  )
                else if (mensagemErro != null)
                  _MensagemHome(
                    icone: Icons.cloud_off_outlined,
                    mensagem: mensagemErro!,
                    textoBotao: 'Tentar novamente',
                    onPressed: carregarCaronas,
                  )
                else if (caronasHome.isEmpty)
                  const _MensagemHome(
                    icone: Icons.directions_car_outlined,
                    mensagem: 'Nenhuma carona disponível',
                  )
                else
                  ListView.separated(
                    itemCount: caronasHome.length,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final carona = caronasHome[index];

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
      ),
    );
  }
}

class _MensagemHome extends StatelessWidget {
  final IconData icone;
  final String mensagem;
  final String? textoBotao;
  final VoidCallback? onPressed;

  const _MensagemHome({
    required this.icone,
    required this.mensagem,
    this.textoBotao,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 28),
        child: Column(
          children: [
            Icon(icone, size: 42, color: Colors.black38),
            const SizedBox(height: 12),
            Text(
              mensagem,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.black54),
            ),
            if (textoBotao != null && onPressed != null)
              TextButton(onPressed: onPressed, child: Text(textoBotao!)),
          ],
        ),
      ),
    );
  }
}
