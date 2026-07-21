import 'package:flutter/material.dart';

import '../config/app_colors.dart';
import '../models/carona.dart';
import '../services/carona_service.dart';
import '../utils/data_hora_utils.dart';
import '../utils/filtro_caronas.dart';
import '../widgets/card_carona_disponivel.dart';
import '../widgets/filtros_busca_carona.dart';

class BuscarCaronaTela extends StatefulWidget {
  const BuscarCaronaTela({super.key});

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
    final horarioMinimo = horarioSelecionado == null
        ? null
        : (horarioSelecionado!.hour * 60) + horarioSelecionado!.minute;

    final resultado = FiltroCaronas.aplicar(
      caronas: todasCaronas,
      destino: destinoController.text,
      data: dataSelecionada,
      horarioMinimoEmMinutos: horarioMinimo,
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
      textoAjuda: 'Mostrar caronas a partir de',
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

  void limparFiltros() {
    destinoController.clear();
    dataController.clear();
    horarioController.clear();

    setState(() {
      dataSelecionada = null;
      horarioSelecionado = null;
    });

    aplicarFiltros();
  }

  void abrirDetalhes(Carona carona) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Detalhes da carona de ${carona.motorista}')),
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
      appBar: AppBar(
        title: const Text('Buscar carona'),
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.text,
        elevation: 0,
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
                onDestinoChanged: (_) => aplicarFiltros(),
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
                const _EstadoBusca(
                  carregando: true,
                  mensagem: 'Carregando caronas...',
                  icone: Icons.directions_car_outlined,
                )
              else if (mensagemErro != null)
                _EstadoBusca(
                  mensagem: mensagemErro!,
                  icone: Icons.cloud_off_outlined,
                  textoBotao: 'Tentar novamente',
                  onPressed: carregarCaronas,
                )
              else if (caronasFiltradas.isEmpty)
                _EstadoBusca(
                  mensagem: filtrosAtivos
                      ? 'Nenhuma carona corresponde aos filtros'
                      : 'Nenhuma carona disponível',
                  icone: Icons.search_off,
                  textoBotao: filtrosAtivos ? 'Limpar filtros' : null,
                  onPressed: filtrosAtivos ? limparFiltros : null,
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

class _EstadoBusca extends StatelessWidget {
  final bool carregando;
  final String mensagem;
  final IconData icone;
  final String? textoBotao;
  final VoidCallback? onPressed;

  const _EstadoBusca({
    this.carregando = false,
    required this.mensagem,
    required this.icone,
    this.textoBotao,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 36),
      child: Column(
        children: [
          if (carregando)
            const CircularProgressIndicator()
          else
            Icon(icone, size: 44, color: Colors.black38),
          const SizedBox(height: 14),
          Text(
            mensagem,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.black54),
          ),
          if (textoBotao != null && onPressed != null)
            TextButton(onPressed: onPressed, child: Text(textoBotao!)),
        ],
      ),
    );
  }
}
