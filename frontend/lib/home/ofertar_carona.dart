import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../config/app_colors.dart';
import '../mapa/models/localizacao_selecionada.dart';
import '../mapa/screens/mapa_screen.dart';
import '../mapa/utils/rota_mapa_utils.dart';
import '../models/carona.dart';
import '../models/capacidade_carona.dart';
import '../models/ponto_embarque.dart';
import '../models/verificacao_cnh.dart';
import '../navigation/navegacao_principal.dart';
import '../services/carona_service.dart';
import '../services/auth_service.dart';
import '../utils/data_hora_utils.dart';
import '../utils/formatador_moeda.dart';
import '../widgets/barra_navegacao_home.dart';
import '../widgets/componentes_padrao.dart';
import '../widgets/formulario_ofertar_carona.dart';
import 'verificacao_cnh.dart';

class OfertarCaronaTela extends StatefulWidget {
  final LocalizacaoSelecionada? destinoInicial;
  final Carona? caronaParaEditar;
  final int? idRecorrencia;
  final int indiceNavegacao;
  final Future<Map<String, dynamic>> Function()? carregarPerfil;
  final Future<Map<String, dynamic>> Function()? carregarCapacidade;
  final Future<LocalizacaoSelecionada?> Function()? selecionarPontoEmbarque;

  const OfertarCaronaTela({
    super.key,
    this.destinoInicial,
    this.caronaParaEditar,
    this.idRecorrencia,
    this.indiceNavegacao = 0,
    this.carregarPerfil,
    this.carregarCapacidade,
    this.selecionarPontoEmbarque,
  });

  @override
  State<OfertarCaronaTela> createState() => _OfertarCaronaTelaState();
}

class _OfertarCaronaTelaState extends State<OfertarCaronaTela> {
  final destinoController = TextEditingController();
  final dataController = TextEditingController();
  final horarioController = TextEditingController();
  final vagasController = TextEditingController();
  final valorController = TextEditingController();
  final observacoesController = TextEditingController();

  LocalizacaoSelecionada? destinoSelecionado;

  DateTime? dataSelecionada;
  TimeOfDay? horarioSelecionado;

  bool caronaRecorrente = false;
  bool enviandoCarona = false;
  bool carregandoCnh = false;
  bool carregandoCapacidade = false;
  String? erroCapacidade;
  CapacidadeCarona? capacidade;
  String? erroCnh;
  Map<String, dynamic>? perfilOferta;
  VerificacaoCnh verificacaoCnh = const VerificacaoCnh();

  final List<String> diasSelecionados = [];
  final List<PontoEmbarque> pontosEmbarque = [];

  bool get editando => widget.caronaParaEditar != null;
  bool get edicaoIndividual => editando && widget.idRecorrencia == null;
  bool get edicaoLimitada => edicaoIndividual && (capacidade?.aceitos ?? 0) > 0;
  bool get precisaCnh => !editando || widget.idRecorrencia != null;

  LocalizacaoSelecionada? get inicioDaOferta {
    if (edicaoIndividual) {
      final carona = widget.caronaParaEditar!;
      if (!coordenadaValida(carona.origemLatitude, carona.origemLongitude)) {
        return null;
      }
      return LocalizacaoSelecionada(
        ponto: LatLng(carona.origemLatitude!, carona.origemLongitude!),
        endereco: carona.origem,
        cidade: carona.origemCidade,
      );
    }
    if (pontosEmbarque.isEmpty) return null;
    final primeiro = pontosEmbarque.first;
    if (!coordenadaValida(primeiro.latitude, primeiro.longitude)) return null;
    return LocalizacaoSelecionada(
      ponto: LatLng(primeiro.latitude, primeiro.longitude),
      endereco: primeiro.endereco,
    );
  }

  bool get possuiVeiculo =>
      editando ||
      (perfilOferta ?? AuthService.usuarioLogado)?['veiculo'] is Map;

  @override
  void initState() {
    super.initState();
    vagasController.text = '1';
    if (precisaCnh) atualizarCnh();

    final carona = widget.caronaParaEditar;

    if (carona != null) {
      _preencherEdicao(carona);
      return;
    }

    destinoSelecionado = widget.destinoInicial;
    destinoController.text = widget.destinoInicial?.descricaoCompleta ?? '';
  }

  Future<void> atualizarCnh() async {
    setState(() {
      carregandoCnh = true;
      erroCnh = null;
    });
    try {
      final perfil =
          await (widget.carregarPerfil?.call() ?? AuthService.buscarPerfil())
              .timeout(const Duration(seconds: 15));
      if (!mounted) return;
      if (perfil['sucesso'] == true && perfil['dados'] is Map) {
        perfilOferta = Map<String, dynamic>.from(perfil['dados']);
        verificacaoCnh = VerificacaoCnh.fromPerfil(perfilOferta!);
      } else {
        erroCnh =
            perfil['mensagem']?.toString() ??
            'Não foi possível conferir sua habilitação';
      }
    } catch (_) {
      if (mounted) {
        erroCnh = 'Não foi possível conferir sua habilitação. Tente novamente';
      }
    } finally {
      if (mounted) setState(() => carregandoCnh = false);
    }
  }

  Future<void> abrirVerificacaoCnh() async {
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            VerificacaoCnhTela(carregarPerfil: widget.carregarPerfil),
      ),
    );
    if (mounted) await atualizarCnh();
  }

  void _preencherEdicao(Carona carona) {
    destinoController.text = carona.destino;

    dataSelecionada = carona.dataInicio;
    dataController.text = DataHoraUtils.formatarDataExibicao(carona.dataInicio);

    horarioSelecionado = _converterHorario(carona.horario);
    horarioController.text = horarioSelecionado == null
        ? carona.horario
        : DataHoraUtils.formatarHorario(horarioSelecionado!);

    if (edicaoIndividual) {
      vagasController.clear();
      atualizarCapacidade();
    } else {
      vagasController.text = carona.vagas.toString();
    }
    valorController.text = formatarDoubleComoMoedaReal(carona.valor);
    observacoesController.text = carona.observacoes ?? '';

    caronaRecorrente = carona.recorrente;
    diasSelecionados.addAll(carona.diasSemana);

    // Carrega os pontos que já pertencem a essa carona.
    pontosEmbarque.addAll(
      [...carona.pontosEmbarque]..sort((a, b) => a.ordem.compareTo(b.ordem)),
    );

    if (carona.destinoLatitude != null && carona.destinoLongitude != null) {
      destinoSelecionado = LocalizacaoSelecionada(
        ponto: LatLng(carona.destinoLatitude!, carona.destinoLongitude!),
        endereco: carona.destino,
        cidade: carona.destinoCidade,
      );
    }
  }

  Future<void> atualizarCapacidade() async {
    if (carregandoCapacidade) return;
    setState(() {
      carregandoCapacidade = true;
      erroCapacidade = null;
    });
    try {
      final resultado =
          await (widget.carregarCapacidade?.call() ??
                  CaronaService.buscarCapacidade(widget.caronaParaEditar!.id))
              .timeout(const Duration(seconds: 20));
      if (!mounted) return;
      final dados = resultado['dados'];
      if (resultado['sucesso'] == true && dados is CapacidadeCarona) {
        capacidade = dados;
        vagasController.text = dados.total.toString();
      } else {
        erroCapacidade =
            resultado['mensagem']?.toString() ??
            'Não foi possível conferir as vagas';
      }
    } catch (_) {
      if (mounted) {
        erroCapacidade = 'Não foi possível conferir as vagas. Tente novamente';
      }
    } finally {
      if (mounted) setState(() => carregandoCapacidade = false);
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

  Future<void> escolherDestinoNoMapa() async {
    final resultado = await Navigator.push<LocalizacaoSelecionada>(
      context,
      MaterialPageRoute(
        builder: (context) => TesteMapa(
          indiceNavegacao: widget.indiceNavegacao,
          titulo: 'Confirmar destino',
          ajusteOpcional: true,
          instrucao: 'Confira o destino',
          textoBotao: 'CONFIRMAR DESTINO',
        ),
      ),
    );

    if (!mounted || resultado == null) {
      return;
    }

    setState(() {
      destinoSelecionado = resultado;
      destinoController.text = resultado.descricaoCompleta;
    });
  }

  // Usa o mesmo mapa para cadastrar um ponto de embarque.
  Future<void> adicionarPontoEmbarque() async {
    if (editando && widget.idRecorrencia == null) {
      return;
    }

    final resultado =
        await (widget.selecionarPontoEmbarque?.call() ??
            Navigator.push<LocalizacaoSelecionada>(
              context,
              MaterialPageRoute(
                builder: (context) => TesteMapa(
                  indiceNavegacao: widget.indiceNavegacao,
                  titulo: 'Ponto de encontro',
                  ajusteOpcional: true,
                  instrucao: 'Escolha onde os passageiros poderão embarcar',
                  textoBotao: 'ADICIONAR PONTO',
                ),
              ),
            ));

    if (!mounted || resultado == null) {
      return;
    }

    if (!resultado.localConfirmavel) {
      mostrarMensagem(
        'Escolha um ponto de encontro específico com endereço válido',
      );
      return;
    }

    final pontoJaExiste = pontosEmbarque.any(
      (ponto) =>
          ponto.latitude == resultado.ponto.latitude &&
          ponto.longitude == resultado.ponto.longitude,
    );

    if (pontoJaExiste) {
      mostrarMensagem('Esse ponto de encontro já foi adicionado');
      return;
    }

    setState(() {
      pontosEmbarque.add(
        PontoEmbarque(
          nome: resultado.nome,
          endereco: resultado.endereco,
          latitude: resultado.ponto.latitude,
          longitude: resultado.ponto.longitude,
          ordem: pontosEmbarque.length + 1,
        ),
      );
    });
  }

  void removerPontoEmbarque(int indice) {
    if ((editando && widget.idRecorrencia == null) ||
        indice < 0 ||
        indice >= pontosEmbarque.length) {
      return;
    }

    setState(() {
      pontosEmbarque.removeAt(indice);
      for (var i = indice; i < pontosEmbarque.length; i++) {
        final ponto = pontosEmbarque[i];
        pontosEmbarque[i] = PontoEmbarque(
          id: ponto.id,
          nome: ponto.nome,
          endereco: ponto.endereco,
          latitude: ponto.latitude,
          longitude: ponto.longitude,
          ordem: i + 1,
          percorridoEm: ponto.percorridoEm,
        );
      }
    });
  }

  Future<void> escolherData() async {
    if (widget.idRecorrencia == null &&
        widget.caronaParaEditar?.idRecorrencia != null) {
      mostrarMensagem(
        'Esta data pertence à programação. Para outra data, publique uma carona avulsa.',
      );
      return;
    }
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

  // Invalida o destino antigo quando o texto muda.
  void alterarTextoDestino(String texto) {
    if (destinoSelecionado == null ||
        texto == destinoSelecionado!.descricaoCompleta) {
      return;
    }

    setState(() {
      destinoSelecionado = null;
    });
  }

  void selecionarDestino(LocalizacaoSelecionada destino) {
    setState(() {
      destinoSelecionado = destino;
      destinoController.text = destino.descricaoCompleta;
    });
  }

  void alterarRecorrencia(bool valor) {
    if (widget.idRecorrencia != null && !valor) {
      mostrarMensagem(
        'Para interromper a programação, use Pausar em Recorrências',
      );
      return;
    }
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

  // Valida e envia a oferta para o backend.
  Future<void> ofertarCarona() async {
    if (enviandoCarona) return;
    if (precisaCnh && !verificacaoCnh.permiteOferecerCarona()) {
      await abrirVerificacaoCnh();
      return;
    }
    if (!possuiVeiculo) {
      mostrarMensagem(
        'Cadastre seu veículo no perfil antes de oferecer uma carona',
      );
      return;
    }

    final erro = validarFormulario();

    if (erro != null) {
      mostrarMensagem(erro);
      return;
    }

    setState(() {
      enviandoCarona = true;
    });

    final origem = inicioDaOferta!;
    final destino = destinoSelecionado!;
    final observacoes = observacoesController.text.trim();

    final resultado = await CaronaService.salvarCarona(
      idCarona: widget.caronaParaEditar?.id,
      idRecorrencia: widget.idRecorrencia,

      origem: origem.endereco,
      origemCidade: origem.cidade,
      origemLatitude: origem.ponto.latitude,
      origemLongitude: origem.ponto.longitude,

      destino: destino.descricaoCompleta,
      destinoCidade: destino.cidade ?? widget.caronaParaEditar?.destinoCidade,
      destinoLatitude: destino.ponto.latitude,
      destinoLongitude: destino.ponto.longitude,

      pontosEmbarque: pontosEmbarque,

      dataInicio: DataHoraUtils.formatarDataBackend(dataSelecionada!),
      dataFim: widget.caronaParaEditar?.dataFim == null
          ? null
          : DataHoraUtils.formatarDataBackend(
              widget.caronaParaEditar!.dataFim!,
            ),
      horario: edicaoLimitada
          ? widget.caronaParaEditar!.horario
          : '${DataHoraUtils.formatarHorario(horarioSelecionado!)}:00',
      vagas: int.parse(vagasController.text),
      capacidadePassageiros: edicaoIndividual
          ? int.parse(vagasController.text)
          : null,
      capacidadeAnterior: edicaoIndividual ? capacidade?.total : null,
      valor: edicaoLimitada
          ? widget.caronaParaEditar!.valor
          : converterMoedaRealParaDouble(valorController.text),
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

      if (Navigator.canPop(context)) {
        Navigator.pop(context, true);
      }

      return;
    }

    if (resultado['codigo'] == 'CNH_NAO_APROVADA') {
      await atualizarCnh();
      if (!mounted) return;
    }
    mostrarMensagem(
      resultado['mensagem']?.toString() ?? 'Erro ao criar carona',
    );
  }

  String? validarFormulario() {
    if (edicaoIndividual &&
        (carregandoCapacidade ||
            erroCapacidade != null ||
            capacidade == null)) {
      return 'Confira a capacidade da carona antes de salvar';
    }
    final camposObrigatorios = [
      destinoController.text,
      dataController.text,
      horarioController.text,
      vagasController.text,
      valorController.text,
    ];

    if (camposObrigatorios.any((campo) => campo.trim().isEmpty)) {
      return 'Preencha todos os campos obrigatórios';
    }

    if (destinoSelecionado == null) {
      return 'Busque e selecione o destino';
    }

    if ((!editando || widget.idRecorrencia != null) && pontosEmbarque.isEmpty) {
      return 'Adicione pelo menos um ponto de encontro';
    }
    if (pontosEmbarque.any(
      (ponto) =>
          !coordenadaValida(ponto.latitude, ponto.longitude) ||
          ponto.endereco.trim().isEmpty,
    )) {
      return 'Confira o endereço e as coordenadas dos pontos de encontro';
    }
    if (inicioDaOferta == null || inicioDaOferta!.endereco.trim().isEmpty) {
      return 'Não foi possível conferir o início da carona';
    }

    if (dataSelecionada == null || horarioSelecionado == null) {
      return 'Selecione a data e o horário';
    }

    final vagas = int.tryParse(vagasController.text);

    if (vagas == null || vagas <= 0 || vagas > 4) {
      return 'Informe entre 1 e 4 vagas';
    }
    if (edicaoIndividual && vagas < capacidade!.aceitos) {
      return 'A capacidade não pode ser menor que a quantidade de passageiros aceitos';
    }
    if (edicaoLimitada && vagas < capacidade!.total) {
      return 'Com passageiros aceitos, a capacidade só pode ser aumentada';
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

  Future<void> abrirCadastroVeiculo() async {
    await Navigator.pushNamed(context, NavegacaoPrincipal.rotaPerfil);

    if (mounted) {
      if (precisaCnh) await atualizarCnh();
      if (!mounted) return;
      setState(() {});
    }
  }

  @override
  void dispose() {
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
        titulo: widget.idRecorrencia != null
            ? 'Editar recorrência'
            : editando
            ? 'Editar carona'
            : 'Ofertar carona',
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
        child:
            precisaCnh &&
                (carregandoCnh ||
                    erroCnh != null ||
                    !verificacaoCnh.permiteOferecerCarona())
            ? SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: EstadoConteudoPadrao(
                    carregando: carregandoCnh,
                    icone: Icons.badge_outlined,
                    titulo: carregandoCnh
                        ? 'Conferindo sua habilitação'
                        : erroCnh != null
                        ? 'Não foi possível continuar'
                        : 'Verifique sua CNH',
                    mensagem: carregandoCnh
                        ? null
                        : erroCnh ??
                              'Para oferecer caronas, precisamos conferir uma CNH válida para dirigir automóveis',
                    textoBotao: carregandoCnh
                        ? null
                        : erroCnh != null
                        ? 'Tentar novamente'
                        : 'Verificar CNH',
                    iconeBotao: erroCnh != null
                        ? Icons.refresh
                        : Icons.badge_outlined,
                    onPressed: carregandoCnh
                        ? null
                        : erroCnh != null
                        ? atualizarCnh
                        : abrirVerificacaoCnh,
                  ),
                ),
              )
            : edicaoIndividual &&
                  (carregandoCapacidade ||
                      erroCapacidade != null ||
                      capacidade == null)
            ? SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: EstadoConteudoPadrao(
                  carregando: carregandoCapacidade,
                  icone: Icons.people_outline,
                  titulo: carregandoCapacidade
                      ? 'Conferindo vagas'
                      : 'Não foi possível continuar',
                  mensagem: erroCapacidade,
                  textoBotao: carregandoCapacidade ? null : 'Tentar novamente',
                  iconeBotao: Icons.refresh,
                  onPressed: carregandoCapacidade ? null : atualizarCapacidade,
                ),
              )
            : SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: FormularioOfertarCarona(
                  titulo: widget.idRecorrencia != null
                      ? 'Editar recorrência'
                      : editando
                      ? 'Editar carona'
                      : 'Ofertar carona',
                  descricao: widget.idRecorrencia != null
                      ? 'Alterações valem para novas datas. Caronas já publicadas são mantidas.'
                      : edicaoLimitada
                      ? 'Passageiros confirmados. Dados da viagem bloqueados.'
                      : editando
                      ? 'Atualize os dados da viagem'
                      : 'Informe os dados da viagem',
                  textoBotao: editando ? 'SALVAR ALTERAÇÕES' : 'OFERTAR CARONA',
                  textoCarregando: editando ? 'SALVANDO...' : 'ENVIANDO...',

                  destinoController: destinoController,
                  dataController: dataController,
                  horarioController: horarioController,
                  vagasController: vagasController,
                  passageirosAceitos: edicaoIndividual
                      ? capacidade?.aceitos
                      : null,
                  capacidadeMinima: edicaoLimitada ? capacidade!.total : 1,
                  valorController: valorController,
                  observacoesController: observacoesController,

                  caronaRecorrente: caronaRecorrente,
                  enviandoCarona: enviandoCarona,
                  diasSelecionados: diasSelecionados,

                  pontosEmbarque: pontosEmbarque,
                  referenciaDestino: destinoSelecionado,
                  pontosEmbarqueEditaveis:
                      !editando || widget.idRecorrencia != null,
                  mostrarRecorrencia: !editando || widget.idRecorrencia != null,
                  possuiVeiculo: possuiVeiculo,

                  onSelecionarDestino: escolherDestinoNoMapa,
                  onAdicionarPontoEmbarque: adicionarPontoEmbarque,
                  onRemoverPontoEmbarque: removerPontoEmbarque,
                  onSelecionarData: escolherData,
                  onSelecionarHorario: escolherHorario,
                  onDestinoChanged: alterarTextoDestino,
                  onDestinoSelecionado: selecionarDestino,
                  onRecorrenciaChanged: alterarRecorrencia,
                  onDiaSelecionado: alternarDiaSemana,
                  onOfertarCarona: ofertarCarona,
                  onCadastrarVeiculo: abrirCadastroVeiculo,
                ),
              ),
      ),
    );
  }
}
