import 'package:flutter/material.dart';

import '../config/app_colors.dart';
import '../mapa/models/localizacao_selecionada.dart';
import '../mapa/screens/mapa_screen.dart';
import '../mapa/services/endereco_service.dart';
import '../widgets/formulario_ofertar_carona.dart';

class OfertarCaronaTela extends StatefulWidget {
  const OfertarCaronaTela({super.key});

  @override
  State<OfertarCaronaTela> createState() => _OfertarCaronaTelaState();
}

class _OfertarCaronaTelaState extends State<OfertarCaronaTela> {
  // Campos preenchidos pelo usuario.
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

  final List<String> diasSelecionados = [];

  // Abre o mapa com a localizacao atual estimada.
  Future<void> escolherOrigemNoMapa() async {
    final resultado = await Navigator.push<LocalizacaoSelecionada>(
      context,
      MaterialPageRoute(builder: (context) => const TesteMapa()),
    );

    if (!mounted || resultado == null) {
      return;
    }

    setState(() {
      origemSelecionada = resultado;
      origemController.text = resultado.endereco;
    });
  }

  // Abre o calendario sem permitir datas anteriores a hoje.
  Future<void> escolherData() async {
    final agora = DateTime.now();
    final hoje = DateTime(agora.year, agora.month, agora.day);

    final resultado = await showDatePicker(
      context: context,
      initialDate: dataSelecionada ?? hoje,
      firstDate: hoje,
      lastDate: DateTime(hoje.year + 2, hoje.month, hoje.day),
      helpText: 'Selecione a data da carona',
      cancelText: 'CANCELAR',
      confirmText: 'CONFIRMAR',
    );

    if (!mounted || resultado == null) {
      return;
    }

    setState(() {
      dataSelecionada = resultado;
      dataController.text = _formatarData(resultado);
    });
  }

  // Abre o seletor de horario seguindo o formato do celular.
  Future<void> escolherHorario() async {
    final resultado = await showTimePicker(
      context: context,
      initialTime: horarioSelecionado ?? TimeOfDay.now(),
      helpText: 'Selecione o horario da carona',
      cancelText: 'CANCELAR',
      confirmText: 'CONFIRMAR',
    );

    if (!mounted || resultado == null) {
      return;
    }

    setState(() {
      horarioSelecionado = resultado;
      horarioController.text = _formatarHorario(resultado);
    });
  }

  String _formatarData(DateTime data) {
    final dia = data.day.toString().padLeft(2, '0');
    final mes = data.month.toString().padLeft(2, '0');

    return '$dia/$mes/${data.year}';
  }

  String _formatarHorario(TimeOfDay horario) {
    final hora = horario.hour.toString().padLeft(2, '0');
    final minuto = horario.minute.toString().padLeft(2, '0');

    return '$hora:$minuto';
  }

  // Invalida a localizacao anterior quando o texto for alterado.
  void alterarTextoDestino(String texto) {
    if (destinoSelecionado == null || texto == destinoSelecionado!.endereco) {
      return;
    }

    setState(() {
      destinoSelecionado = null;
    });
  }

  // Busca enderecos correspondentes ao destino digitado.
  Future<void> buscarDestino() async {
    final textoBusca = destinoController.text.trim();

    if (textoBusca.isEmpty) {
      _mostrarMensagem('Digite o destino');
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

    // Ignora resultados antigos caso o texto tenha mudado durante a busca.
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
      _mostrarMensagem('Nenhum destino encontrado');
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

  // Mostra os enderecos encontrados para o usuario escolher.
  Future<LocalizacaoSelecionada?> mostrarOpcoesDestino(
    List<LocalizacaoSelecionada> opcoes,
  ) {
    return showModalBottomSheet<LocalizacaoSelecionada>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
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
                  padding: const EdgeInsets.symmetric(vertical: 8),
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
        );
      },
    );
  }

  void selecionarDestino(LocalizacaoSelecionada destino) {
    setState(() {
      destinoSelecionado = destino;
      destinoController.text = destino.endereco;
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

  // Confere os dados antes de enviar futuramente ao backend.
  void ofertarCarona() {
    final erro = validarFormulario();

    if (erro != null) {
      _mostrarMensagem(erro);
      return;
    }

    // Temporario: a integracao com CaronaService sera o proximo passo.
    _mostrarMensagem('Oferta de carona criada com sucesso');
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
      return 'Preencha todos os campos obrigatorios';
    }

    if (origemSelecionada == null) {
      return 'Confirme a origem pelo mapa';
    }

    if (destinoSelecionado == null) {
      return 'Busque e selecione o destino';
    }

    final vagas = int.tryParse(vagasController.text);

    if (vagas == null || vagas <= 0) {
      return 'Informe uma quantidade de vagas valida';
    }

    if (caronaRecorrente && diasSelecionados.isEmpty) {
      return 'Selecione pelo menos um dia da semana';
    }

    return null;
  }

  void _mostrarMensagem(String mensagem) {
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
      appBar: AppBar(
        title: const Text('Ofertar carona'),
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.text,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: FormularioOfertarCarona(
            origemController: origemController,
            destinoController: destinoController,
            dataController: dataController,
            horarioController: horarioController,
            vagasController: vagasController,
            valorController: valorController,
            observacoesController: observacoesController,
            buscandoDestino: buscandoDestino,
            caronaRecorrente: caronaRecorrente,
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
