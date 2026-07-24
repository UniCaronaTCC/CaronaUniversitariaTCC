import 'package:flutter/material.dart';

import '../config/app_colors.dart';
import '../mapa/models/localizacao_selecionada.dart';
import '../models/carona.dart';
import '../navigation/navegacao_principal.dart';
import '../services/carona_service.dart';
import '../utils/filtro_caronas.dart';
import '../widgets/barra_navegacao_home.dart';
import '../widgets/botao_acao_home.dart';
import '../widgets/card_carona_disponivel.dart';
import '../widgets/card_destino_home.dart';
import '../widgets/componentes_padrao.dart';
import 'buscar_carona.dart';
import 'detalhes_carona.dart';
import 'minhas_caronas.dart';
import 'ofertar_carona.dart';
import 'selecionar_destino.dart';

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
  LocalizacaoSelecionada? destinoSelecionado;

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
      MaterialPageRoute(
        builder: (context) =>
            BuscarCaronaTela(destinoInicial: destinoSelecionado),
      ),
    );

    // Atualiza a Home ao voltar da busca.
    await carregarCaronas();
  }

  Future<void> abrirOferta() async {
    final caronaCriada = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) =>
            OfertarCaronaTela(destinoInicial: destinoSelecionado),
      ),
    );

    // Atualiza imediatamente depois de criar uma oferta.
    if (caronaCriada == true) {
      await carregarCaronas();
    }
  }

  Future<void> escolherDestino() async {
    final resultado = await Navigator.push<LocalizacaoSelecionada>(
      context,
      MaterialPageRoute(
        builder: (context) =>
            SelecionarDestinoTela(destinoInicial: destinoSelecionado),
      ),
    );

    if (!mounted || resultado == null) {
      return;
    }

    setState(() {
      destinoSelecionado = resultado;
    });
  }

  void abrirDetalhes(Carona carona) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DetalhesCaronaTela(carona: carona),
      ),
    );
  }

  Future<void> navegarBarraInferior(int index) async {
    if (index != 2) {
      await NavegacaoPrincipal.selecionar(context, index, indiceAtual: 0);
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const MinhasCaronasTela()),
    );

    // Atualiza a Home caso uma solicitação tenha sido respondida.
    await carregarCaronas();
  }

  @override
  Widget build(BuildContext context) {
    final caronasOrdenadas = FiltroCaronas.aplicar(
      caronas: caronas,
      destino: destinoSelecionado?.descricaoCompleta ?? '',
      destinoLatitude: destinoSelecionado?.ponto.latitude,
      destinoLongitude: destinoSelecionado?.ponto.longitude,
    );
    final caronasHome = caronasOrdenadas.take(3).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      bottomNavigationBar: BarraNavegacaoHome(onTap: navegarBarraInferior),
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

                CardDestinoHome(
                  destino:
                      destinoSelecionado?.descricaoCompleta ??
                      'Escolha seu destino',
                  onTap: escolherDestino,
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
                  const EstadoConteudoPadrao(
                    carregando: true,
                    espacamentoVertical: 32,
                  )
                else if (mensagemErro != null)
                  EstadoConteudoPadrao(
                    icone: Icons.cloud_off_outlined,
                    mensagem: mensagemErro!,
                    textoBotao: 'Tentar novamente',
                    onPressed: carregarCaronas,
                  )
                else if (caronasHome.isEmpty)
                  const EstadoConteudoPadrao(
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
