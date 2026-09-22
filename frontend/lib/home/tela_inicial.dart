import 'package:flutter/material.dart';

import '../config/app_colors.dart';
import '../mapa/models/localizacao_selecionada.dart';
import '../mapa/services/endereco_service.dart';
import '../mapa/services/localizacao_service.dart';
import '../models/carona.dart';
import '../navigation/navegacao_principal.dart';
import '../services/carona_service.dart';
import '../utils/filtro_caronas.dart';
import '../widgets/barra_navegacao_home.dart';
import '../widgets/botao_acao_home.dart';
import '../widgets/card_carona_disponivel.dart';
import '../widgets/card_destino_home.dart';
import '../widgets/componentes_padrao.dart';
import '../widgets/secao_caronas_publicadas.dart';
import 'buscar_carona.dart';
import 'caronas_publicadas.dart';
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
  final LocalizacaoService localizacaoService = LocalizacaoService();
  final EnderecoService enderecoService = EnderecoService();

  List<Carona> caronas = [];
  List<Carona> minhasCaronas = [];
  bool carregando = true;
  bool carregandoMinhasCaronas = true;
  String? mensagemErro;
  String? mensagemErroMinhasCaronas;
  LocalizacaoSelecionada? destinoSelecionado;
  String? cidadeAtual;

  @override
  void initState() {
    super.initState();
    carregarConteudo();
    carregarCidadeAtual();
  }

  Future<void> carregarConteudo() async {
    await Future.wait([
      carregarCaronas(),
      carregarMinhasCaronas(),
    ]);
  }

  Future<void> carregarCidadeAtual() async {
    try {
      final posicao = await localizacaoService.obterLocalizacaoAtual();
      final localizacao = await enderecoService.buscarLocalizacaoPorCoordenadas(
        posicao.latitude,
        posicao.longitude,
      );

      if (!mounted || localizacao?.cidade == null) {
        return;
      }

      setState(() {
        cidadeAtual = localizacao!.cidade;
      });
    } catch (erro) {
      debugPrint('Não foi possível identificar a cidade atual: $erro');
    }
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

  Future<void> carregarMinhasCaronas() async {
    setState(() {
      carregandoMinhasCaronas = true;
      mensagemErroMinhasCaronas = null;
    });

    final resultado = await CaronaService.listarMinhasCaronas();

    if (!mounted) {
      return;
    }

    final dados = resultado['dados'];

    if (resultado['sucesso'] == true && dados is List<Carona>) {
      final caronasAtivas = dados
          .where((carona) => !carona.finalizada)
          .toList()
        ..sort((a, b) => a.dataInicio.compareTo(b.dataInicio));

      setState(() {
        minhasCaronas = caronasAtivas;
        carregandoMinhasCaronas = false;
      });
      return;
    }

    setState(() {
      carregandoMinhasCaronas = false;
      mensagemErroMinhasCaronas =
          resultado['mensagem']?.toString() ??
          'Não foi possível carregar suas caronas';
    });
  }

  Future<void> abrirBusca() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BuscarCaronaTela(
          destinoInicial: destinoSelecionado,
          cidadeInicial: cidadeAtual,
        ),
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
      await carregarConteudo();
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

  Future<void> abrirCaronaPublicada(Carona carona) async {
    final alterada = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => DetalhesCaronaTela(
          carona: carona,
          indiceNavegacaoOrigem: 0,
        ),
      ),
    );

    if (alterada == true) {
      await carregarConteudo();
    }
  }

  Future<void> abrirTodasCaronasPublicadas() async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(builder: (_) => const CaronasPublicadasTela()),
    );

    if (mounted) {
      await carregarMinhasCaronas();
    }
  }

  Future<void> editarCaronaPublicada(Carona carona) async {
    final alterada = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => OfertarCaronaTela(
          caronaParaEditar: carona,
          indiceNavegacao: 0,
        ),
      ),
    );

    if (alterada == true) {
      await carregarConteudo();
    }
  }

  Future<void> cancelarCaronaPublicada(Carona carona) async {
    final confirmou = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancelar carona?'),
        content: const Text(
          'A carona deixará de aparecer para os passageiros.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('VOLTAR'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('CANCELAR CARONA'),
          ),
        ],
      ),
    );

    if (!mounted || confirmou != true) {
      return;
    }

    final resultado = await CaronaService.excluirCarona(carona.id);

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          resultado['mensagem']?.toString() ??
              'Não foi possível cancelar a carona',
        ),
      ),
    );

    if (resultado['sucesso'] == true) {
      await carregarConteudo();
    }
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
    await carregarConteudo();
  }

  @override
  Widget build(BuildContext context) {
    final caronasOrdenadas = FiltroCaronas.aplicar(
      caronas: caronas,
      destino: destinoSelecionado?.descricaoCompleta ?? '',
      destinoLatitude: destinoSelecionado?.ponto.latitude,
      destinoLongitude: destinoSelecionado?.ponto.longitude,
      cidadePreferida: cidadeAtual,
    );
    final caronasHome = caronasOrdenadas.take(3).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      bottomNavigationBar: BarraNavegacaoHome(onTap: navegarBarraInferior),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: carregarConteudo,
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

                if (carregandoMinhasCaronas ||
                    mensagemErroMinhasCaronas != null ||
                    minhasCaronas.isNotEmpty) ...[
                  SecaoCaronasPublicadas(
                    caronas: minhasCaronas,
                    carregando: carregandoMinhasCaronas,
                    mensagemErro: mensagemErroMinhasCaronas,
                    onTentarNovamente: carregarMinhasCaronas,
                    onVerTodas: abrirTodasCaronasPublicadas,
                    onAbrirCarona: abrirCaronaPublicada,
                    onEditarCarona: editarCaronaPublicada,
                    onCancelarCarona: cancelarCaronaPublicada,
                  ),
                  const SizedBox(height: 36),
                ],

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
