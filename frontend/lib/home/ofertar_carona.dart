import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../config/app_colors.dart';
import '../mapa/models/localizacao_selecionada.dart';
import '../mapa/screens/mapa_screen.dart';
import '../mapa/services/endereco_service.dart';
import '../models/carona.dart';
import '../navigation/navegacao_principal.dart';
import '../services/carona_service.dart';
import '../utils/data_hora_utils.dart';
import '../utils/formatador_moeda.dart';
import '../widgets/componentes_padrao.dart';
import '../widgets/barra_navegacao_home.dart';
import '../widgets/formulario_ofertar_carona.dart';

class OfertarCaronaTela extends StatefulWidget {
  final LocalizacaoSelecionada? destinoInicial;
  final Carona? caronaParaEditar;
  final int indiceNavegacao;

  const OfertarCaronaTela({
    super.key,
    this.destinoInicial,
    this.caronaParaEditar,
    this.indiceNavegacao = 0,
  });

  @override
  State<OfertarCaronaTela> createState() => _OfertarCaronaTelaState();
}

class _OfertarCaronaTelaState extends State<OfertarCaronaTela> {
  final origemController = TextEditingController();
  final destinoController = TextEditingController();
  final dataController = TextEditingController();
  final horarioController = TextEditingController();
  final vagasController = TextEditingController();
  final valorController = TextEditingController();
  final observacoesController = TextEditingController();

  final EnderecoService enderecoService = EnderecoService();

  LocalizacaoSelecionada? origemSelecionada;
  LocalizacaoSelecionada? destinoSelecionado;
  DateTime? dataSelecionada;
  TimeOfDay? horarioSelecionado;

  bool buscandoDestino = false;
  bool caronaRecorrente = false;
  bool enviandoCarona = false;

  final List<String> diasSelecionados = [];

  bool get editando => widget.caronaParaEditar != null;

  @override
  void initState() {
    super.initState();

    final carona = widget.caronaParaEditar;

    if (carona != null) {
      _preencherEdicao(carona);
      return;
    }

    destinoSelecionado = widget.destinoInicial;
    destinoController.text = widget.destinoInicial?.descricaoCompleta ?? '';
  }

  void _preencherEdicao(Carona carona) {
    origemController.text = carona.origem;
    destinoController.text = carona.destino;
    dataSelecionada = carona.dataInicio;
    dataController.text = DataHoraUtils.formatarDataExibicao(carona.dataInicio);
    horarioSelecionado = _converterHorario(carona.horario);
    horarioController.text = horarioSelecionado == null
        ? carona.horario
        : DataHoraUtils.formatarHorario(horarioSelecionado!);
    vagasController.text = carona.vagas.toString();
    valorController.text = formatarDoubleComoMoedaReal(carona.valor);
    observacoesController.text = carona.observacoes ?? '';
    caronaRecorrente = carona.recorrente;
    diasSelecionados.addAll(carona.diasSemana);

    if (carona.origemLatitude != null && carona.origemLongitude != null) {
      origemSelecionada = LocalizacaoSelecionada(
        ponto: LatLng(carona.origemLatitude!, carona.origemLongitude!),
        endereco: carona.origem,
      );
    }

    if (carona.destinoLatitude != null && carona.destinoLongitude != null) {
      destinoSelecionado = LocalizacaoSelecionada(
        ponto: LatLng(carona.destinoLatitude!, carona.destinoLongitude!),
        endereco: carona.destino,
      );
    }
  }

  TimeOfDay? _converterHorario(String horario) {
    final partes = horario.split(':');

    if (partes.length < 2) {
      return null;
    }

    final hora = int.tryParse(partes[0]);
    final minuto = int.tryParse(partes[1]);

    if (hora == null || minuto == null) {
      return null;
    }

    return TimeOfDay(hour: hora, minute: minuto);
  }

  // Abre o mapa com a localizacao atual estimada.
  Future<void> escolherOrigemNoMapa() async {
    final resultado = await Navigator.push<LocalizacaoSelecionada>(
      context,
      MaterialPageRoute(
        builder: (context) =>
            TesteMapa(indiceNavegacao: widget.indiceNavegacao),
      ),
    );

    if (!mounted || resultado == null) {
      return;
    }

    setState(() {
      origemSelecionada = resultado;
      origemController.text = resultado.endereco;
    });
  }

  // Abre o calendario sem permitir datas anteriores.
  Future<void> escolherData() async {
    final resultado = await DataHoraUtils.selecionarData(
      context,
      dataInicial: dataSelecionada,
      textoAjuda: 'Selecione a data da carona',
    );

    if (!mounted || resultado == null) {
      return;
    }

    setState(() {
      dataSelecionada = resultado;
      dataController.text = DataHoraUtils.formatarDataExibicao(resultado);
    });
  }

  // Abre o seletor de horario do celular.
  Future<void> escolherHorario() async {
    final resultado = await DataHoraUtils.selecionarHorario(
      context,
      horarioInicial: horarioSelecionado,
      textoAjuda: 'Selecione o horário da carona',
    );

    if (!mounted || resultado == null) {
      return;
    }

    setState(() {
      horarioSelecionado = resultado;
      horarioController.text = DataHoraUtils.formatarHorario(resultado);
    });
  }

  // Invalida a localizacao antiga quando o texto muda.
  void alterarTextoDestino(String texto) {
    if (destinoSelecionado == null ||
        texto == destinoSelecionado!.descricaoCompleta) {
      return;
    }

    setState(() {
      destinoSelecionado = null;
    });
  }

  Future<void> buscarDestino() async {
    final textoBusca = destinoController.text.trim();

    if (textoBusca.isEmpty) {
      mostrarMensagem('Digite o destino');
      return;
    }

    setState(() {
      buscandoDestino = true;
      destinoSelecionado = null;
    });

    final opcoes = await enderecoService.buscarLocalizacoesPorEndereco(
      textoBusca,
    );

    if (!mounted) {
      return;
    }

    // Descarta a resposta se o texto mudou durante a busca.
    if (destinoController.text.trim() != textoBusca) {
      setState(() {
        buscandoDestino = false;
      });
      return;
    }

    setState(() {
      buscandoDestino = false;
    });

    if (opcoes.isEmpty) {
      mostrarMensagem('Nenhum destino encontrado');
      return;
    }

    if (opcoes.length == 1) {
      selecionarDestino(opcoes.first);
      return;
    }

    final resultado = await mostrarOpcoesDestino(opcoes);

    if (!mounted || resultado == null) {
      return;
    }

    selecionarDestino(resultado);
  }

  Future<LocalizacaoSelecionada?> mostrarOpcoesDestino(
    List<LocalizacaoSelecionada> opcoes,
  ) {
    return showModalBottomSheet<LocalizacaoSelecionada>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: SizedBox(
            height: MediaQuery.sizeOf(context).height * 0.6,
            child: Column(
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Text(
                    'Selecione o destino',
                    style: TextStyle(
                      color: AppColors.text,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: ListView.separated(
                    itemCount: opcoes.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final opcao = opcoes[index];

                      return ListTile(
                        leading: const Icon(
                          Icons.location_on_outlined,
                          color: AppColors.primary,
                        ),
                        title: Text(opcao.endereco),
                        onTap: () {
                          Navigator.pop(context, opcao);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void selecionarDestino(LocalizacaoSelecionada destino) {
    setState(() {
      destinoSelecionado = destino;
      destinoController.text = destino.descricaoCompleta;
    });
  }

  void alterarRecorrencia(bool valor) {
    setState(() {
      caronaRecorrente = valor;

      if (!valor) {
        diasSelecionados.clear();
      }
    });
  }

  void alternarDiaSemana(String dia) {
    setState(() {
      if (diasSelecionados.contains(dia)) {
        diasSelecionados.remove(dia);
      } else {
        diasSelecionados.add(dia);
      }
    });
  }

  // Valida e envia a oferta ao backend.
  Future<void> ofertarCarona() async {
    final erro = validarFormulario();

    if (erro != null) {
      mostrarMensagem(erro);
      return;
    }

    setState(() {
      enviandoCarona = true;
    });

    final origem = origemSelecionada!;
    final destino = destinoSelecionado!;
    final observacoes = observacoesController.text.trim();

    final resultado = await CaronaService.salvarCarona(
      idCarona: widget.caronaParaEditar?.id,
      origem: origem.endereco,
      origemCidade: widget.caronaParaEditar?.origemCidade,
      origemLatitude: origem.ponto.latitude,
      origemLongitude: origem.ponto.longitude,

      destino: destino.descricaoCompleta,
      destinoCidade: widget.caronaParaEditar?.destinoCidade,
      destinoLatitude: destino.ponto.latitude,
      destinoLongitude: destino.ponto.longitude,

      dataInicio: DataHoraUtils.formatarDataBackend(dataSelecionada!),
      dataFim: widget.caronaParaEditar?.dataFim == null
          ? null
          : DataHoraUtils.formatarDataBackend(
              widget.caronaParaEditar!.dataFim!,
            ),
      horario: '${DataHoraUtils.formatarHorario(horarioSelecionado!)}:00',
      vagas: int.parse(vagasController.text),
      valor: converterMoedaRealParaDouble(valorController.text),
      recorrente: caronaRecorrente,
      diasSemana: caronaRecorrente ? List<String>.from(diasSelecionados) : null,
      observacoes: observacoes.isEmpty ? null : observacoes,
    );

    if (!mounted) {
      return;
    }

    setState(() {
      enviandoCarona = false;
    });

    if (resultado['sucesso'] == true) {
      final dados = resultado['dados'] as Map<String, dynamic>?;

      mostrarMensagem(
        dados?['mensagem']?.toString() ??
            (editando
                ? 'Carona atualizada com sucesso'
                : 'Carona criada com sucesso'),
      );

      // Volta para a Home quando a tela foi aberta por navegacao.
      if (Navigator.canPop(context)) {
        Navigator.pop(context, true);
      }

      return;
    }

    mostrarMensagem(
      resultado['mensagem']?.toString() ?? 'Erro ao criar carona',
    );
  }

  String? validarFormulario() {
    final camposObrigatorios = [
      origemController.text,
      destinoController.text,
      dataController.text,
      horarioController.text,
      vagasController.text,
      valorController.text,
    ];

    if (camposObrigatorios.any((campo) => campo.trim().isEmpty)) {
      return 'Preencha todos os campos obrigatórios';
    }

    if (origemSelecionada == null) {
      return 'Confirme a origem pelo mapa';
    }

    if (destinoSelecionado == null) {
      return 'Busque e selecione o destino';
    }

    if (dataSelecionada == null || horarioSelecionado == null) {
      return 'Selecione a data e o horário';
    }

    final vagas = int.tryParse(vagasController.text);

    if (vagas == null || vagas <= 0) {
      return 'Informe uma quantidade de vagas válida';
    }

    if (caronaRecorrente && diasSelecionados.isEmpty) {
      return 'Selecione pelo menos um dia da semana';
    }

    return null;
  }

  void mostrarMensagem(String mensagem) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(mensagem)));
  }

  @override
  void dispose() {
    origemController.dispose();
    destinoController.dispose();
    dataController.dispose();
    horarioController.dispose();
    vagasController.dispose();
    valorController.dispose();
    observacoesController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: BarraSuperiorPadrao(
        titulo: editando ? 'Editar carona' : 'Ofertar carona',
      ),
      bottomNavigationBar: BarraNavegacaoHome(
        currentIndex: widget.indiceNavegacao,
        onTap: (indice) => NavegacaoPrincipal.selecionar(
          context,
          indice,
          indiceAtual: widget.indiceNavegacao,
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: FormularioOfertarCarona(
            titulo: editando ? 'Editar carona' : 'Ofertar carona',
            descricao: editando
                ? 'Atualize os dados da viagem'
                : 'Informe os dados da viagem',
            textoBotao: editando ? 'SALVAR ALTERAÇÕES' : 'OFERTAR CARONA',
            textoCarregando: editando ? 'SALVANDO...' : 'ENVIANDO...',
            origemController: origemController,
            destinoController: destinoController,
            dataController: dataController,
            horarioController: horarioController,
            vagasController: vagasController,
            valorController: valorController,
            observacoesController: observacoesController,
            buscandoDestino: buscandoDestino,
            caronaRecorrente: caronaRecorrente,
            enviandoCarona: enviandoCarona,
            diasSelecionados: diasSelecionados,
            onSelecionarOrigem: escolherOrigemNoMapa,
            onBuscarDestino: buscarDestino,
            onSelecionarData: escolherData,
            onSelecionarHorario: escolherHorario,
            onDestinoChanged: alterarTextoDestino,
            onRecorrenciaChanged: alterarRecorrencia,
            onDiaSelecionado: alternarDiaSemana,
            onOfertarCarona: ofertarCarona,
          ),
        ),
      ),
    );
  }
}
