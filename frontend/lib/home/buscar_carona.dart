import 'package:flutter/material.dart';

import '../config/app_colors.dart';
import '../mapa/models/localizacao_selecionada.dart';
import '../models/carona.dart';
import '../navigation/navegacao_principal.dart';
import '../services/carona_service.dart';
import '../utils/data_hora_utils.dart';
import '../utils/filtro_caronas.dart';
import '../widgets/card_carona_disponivel.dart';
import '../widgets/barra_navegacao_home.dart';
import '../widgets/componentes_padrao.dart';
import '../widgets/filtros_busca_carona.dart';
import 'detalhes_carona.dart';

class BuscarCaronaTela extends StatefulWidget {
  final LocalizacaoSelecionada? destinoInicial;
  final String? cidadeInicial;

  const BuscarCaronaTela({super.key, this.destinoInicial, this.cidadeInicial});

  @override
  State<BuscarCaronaTela> createState() => _BuscarCaronaTelaState();
}

class _BuscarCaronaTelaState extends State<BuscarCaronaTela> {
  final destinoController = TextEditingController();
  final dataController = TextEditingController();
  final horarioController = TextEditingController();

  List<Carona> todasCaronas = [];
  List<Carona> caronasFiltradas = [];

  DateTime? dataSelecionada;
  TimeOfDay? horarioSelecionado;
  LocalizacaoSelecionada? destinoSelecionado;

  bool carregando = true;
  String? mensagemErro;

  bool get filtrosAtivos {
    return destinoController.text.isNotEmpty ||
        dataSelecionada != null ||
        horarioSelecionado != null;
  }

  @override
  void initState() {
    super.initState();
    destinoSelecionado = widget.destinoInicial;
    destinoController.text = destinoSelecionado?.descricaoCompleta ?? '';
    carregarCaronas();
  }

  // Busca as ofertas ativas no backend.
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
      final caronas = dados is List<Carona> ? dados : <Carona>[];

      setState(() {
        todasCaronas = caronas;
        carregando = false;
      });

      aplicarFiltros();
      return;
    }

    setState(() {
      carregando = false;
      mensagemErro =
          resultado['mensagem']?.toString() ?? 'Erro ao carregar caronas';
    });
  }

  // Filtra localmente sem fazer uma nova chamada ao backend.
  void aplicarFiltros() {
    final horarioPreferido = horarioSelecionado == null
        ? null
        : (horarioSelecionado!.hour * 60) + horarioSelecionado!.minute;

    final resultado = FiltroCaronas.aplicar(
      caronas: todasCaronas,
      destino: destinoController.text,
      data: dataSelecionada,
      horarioPreferidoEmMinutos: horarioPreferido,
      destinoLatitude: destinoSelecionado?.ponto.latitude,
      destinoLongitude: destinoSelecionado?.ponto.longitude,
      cidadePreferida: widget.cidadeInicial,
    );

    setState(() {
      caronasFiltradas = resultado;
    });
  }

  Future<void> selecionarData() async {
    final resultado = await DataHoraUtils.selecionarData(
      context,
      dataInicial: dataSelecionada,
      textoAjuda: 'Selecione a data desejada',
    );

    if (!mounted || resultado == null) {
      return;
    }

    setState(() {
      dataSelecionada = resultado;
      dataController.text = DataHoraUtils.formatarDataExibicao(resultado);
    });

    aplicarFiltros();
  }

  Future<void> selecionarHorario() async {
    final resultado = await DataHoraUtils.selecionarHorario(
      context,
      horarioInicial: horarioSelecionado,
      textoAjuda: 'Selecione o horário preferido',
    );

    if (!mounted || resultado == null) {
      return;
    }

    setState(() {
      horarioSelecionado = resultado;
      horarioController.text = DataHoraUtils.formatarHorario(resultado);
    });

    aplicarFiltros();
  }

  void atualizarDestino(String texto) {
    if (destinoSelecionado?.descricaoCompleta.trim() != texto.trim()) {
      destinoSelecionado = null;
    }

    aplicarFiltros();
  }

  void selecionarDestino(LocalizacaoSelecionada destino) {
    setState(() {
      destinoSelecionado = destino;
    });

    aplicarFiltros();
  }

  void limparFiltros() {
    destinoController.clear();
    dataController.clear();
    horarioController.clear();

    setState(() {
      dataSelecionada = null;
      horarioSelecionado = null;
      destinoSelecionado = null;
    });

    aplicarFiltros();
  }

  void abrirDetalhes(Carona carona) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DetalhesCaronaTela(carona: carona),
      ),
    );
  }

  @override
  void dispose() {
    destinoController.dispose();
    dataController.dispose();
    horarioController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const BarraSuperiorPadrao(titulo: 'Buscar carona'),
      bottomNavigationBar: BarraNavegacaoHome(
        onTap: (indice) =>
            NavegacaoPrincipal.selecionar(context, indice, indiceAtual: 0),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: carregarCaronas,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(24),
            children: [
              const Text(
                'Buscar carona',
                style: TextStyle(
                  color: AppColors.text,
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Encontre uma viagem para o seu destino',
                style: TextStyle(color: AppColors.text, fontSize: 18),
              ),
              const SizedBox(height: 28),

              FiltrosBuscaCarona(
                destinoController: destinoController,
                dataController: dataController,
                horarioController: horarioController,
                filtrosAtivos: filtrosAtivos,
                onDestinoChanged: atualizarDestino,
                onDestinoSelecionado: selecionarDestino,
                onSelecionarData: selecionarData,
                onSelecionarHorario: selecionarHorario,
                onLimparFiltros: limparFiltros,
              ),

              const SizedBox(height: 32),

              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Caronas encontradas',
                      style: TextStyle(
                        color: AppColors.text,
                        fontSize: 21,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (!carregando && mensagemErro == null)
                    Text(
                      '${caronasFiltradas.length}',
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 14),

              if (carregando)
                const EstadoConteudoPadrao(
                  carregando: true,
                  mensagem: 'Carregando caronas...',
                  espacamentoVertical: 36,
                  espacamentoMensagem: 14,
                )
              else if (mensagemErro != null)
                EstadoConteudoPadrao(
                  mensagem: mensagemErro!,
                  icone: Icons.cloud_off_outlined,
                  textoBotao: 'Tentar novamente',
                  onPressed: carregarCaronas,
                  espacamentoVertical: 36,
                  tamanhoIcone: 44,
                  espacamentoMensagem: 14,
                )
              else if (caronasFiltradas.isEmpty)
                EstadoConteudoPadrao(
                  mensagem: filtrosAtivos
                      ? 'Nenhuma carona corresponde aos filtros'
                      : 'Nenhuma carona disponível',
                  icone: Icons.search_off,
                  textoBotao: filtrosAtivos ? 'Limpar filtros' : null,
                  onPressed: filtrosAtivos ? limparFiltros : null,
                  espacamentoVertical: 36,
                  tamanhoIcone: 44,
                  espacamentoMensagem: 14,
                )
              else
                ListView.separated(
                  itemCount: caronasFiltradas.length,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final carona = caronasFiltradas[index];

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
