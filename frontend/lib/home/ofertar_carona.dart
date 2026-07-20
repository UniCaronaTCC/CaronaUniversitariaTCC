import 'package:flutter/material.dart';
// Importa os componentes visuais do Flutter

import 'package:flutter/services.dart';
// Importa os formatadores dos campos numericos

import '../config/app_colors.dart';
// Importa as cores principais do aplicativo

import '../mapa/models/localizacao_selecionada.dart';
// Model que guarda endereco e coordenadas

import '../mapa/screens/mapa_screen.dart';
// Tela usada para confirmar a origem no mapa

import '../mapa/services/endereco_service.dart';
// Service usado para buscar o destino digitado

import '../utils/formatador_moeda.dart';
// Importa o formatador de valores em real

import '../widgets/botao_acao_home.dart';
// Importa o botao principal da tela

import '../widgets/campo_recorrencia_carona.dart';
// Importa o campo de configuracao da recorrencia

import '../widgets/campo_texto_carona.dart';
// Importa o campo de texto reutilizavel

class OfertarCaronaTela extends StatefulWidget {
  const OfertarCaronaTela({super.key});

  @override
  State<OfertarCaronaTela> createState() =>
      _OfertarCaronaTelaState();
}

class _OfertarCaronaTelaState
    extends State<OfertarCaronaTela> {
  // Controllers responsaveis pelos campos da tela
  final TextEditingController origemController =
  TextEditingController();

  final TextEditingController destinoController =
  TextEditingController();

  final TextEditingController dataController =
  TextEditingController();

  final TextEditingController horarioController =
  TextEditingController();

  final TextEditingController vagasController =
  TextEditingController();

  final TextEditingController valorController =
  TextEditingController();

  final TextEditingController observacoesController =
  TextEditingController();

  // Service responsavel pela busca de enderecos
  final EnderecoService enderecoService = EnderecoService();

  // Guarda a origem confirmada pelo mapa
  LocalizacaoSelecionada? origemSelecionada;

  // Guarda o destino escolhido na busca
  LocalizacaoSelecionada? destinoSelecionado;

  // Guarda a data escolhida no calendario
  DateTime? dataSelecionada;

  // Guarda o horario escolhido
  TimeOfDay? horarioSelecionado;

  // Indica se o destino esta sendo buscado
  bool buscandoDestino = false;

  // Indica se a carona sera recorrente
  bool caronaRecorrente = false;

  // Guarda os dias escolhidos para recorrencia
  final List<String> diasSelecionados = [];

  // Abre o mapa para confirmar ou ajustar a origem
  Future<void> escolherOrigemNoMapa() async {
    final resultado =
    await Navigator.push<LocalizacaoSelecionada>(
      context,
      MaterialPageRoute(
        builder: (context) => const TesteMapa(),
      ),
    );

    // Verifica se a tela ainda esta aberta
    if (!mounted || resultado == null) {
      return;
    }

    // Salva a origem escolhida
    setState(() {
      origemSelecionada = resultado;
      origemController.text = resultado.endereco;
    });
  }

  // Abre o calendario usando a data atual como inicio
  Future<void> escolherData() async {
    final agora = DateTime.now();

    // Remove horario, minutos e segundos da data atual
    final hoje = DateTime(
      agora.year,
      agora.month,
      agora.day,
    );

    final resultado = await showDatePicker(
      context: context,
      initialDate: dataSelecionada ?? hoje,
      firstDate: hoje,
      lastDate: DateTime(
        hoje.year + 2,
        hoje.month,
        hoje.day,
      ),
      helpText: 'Selecione a data da carona',
      cancelText: 'CANCELAR',
      confirmText: 'CONFIRMAR',
    );

    // Verifica se o usuario escolheu uma data
    if (!mounted || resultado == null) {
      return;
    }

    // Formata a data como dia/mes/ano
    final dataFormatada =
        '${resultado.day.toString().padLeft(2, '0')}/'
        '${resultado.month.toString().padLeft(2, '0')}/'
        '${resultado.year}';

    setState(() {
      dataSelecionada = resultado;
      dataController.text = dataFormatada;
    });
  }

  // Abre o seletor de horario do Flutter
  Future<void> escolherHorario() async {
    final resultado = await showTimePicker(
      context: context,
      initialTime: horarioSelecionado ?? TimeOfDay.now(),
      helpText: 'Selecione o horario da carona',
      cancelText: 'CANCELAR',
      confirmText: 'CONFIRMAR',
    );

    // Verifica se o usuario escolheu um horario
    if (!mounted || resultado == null) {
      return;
    }

    // Formata o horario usando sempre dois digitos
    final horarioFormatado =
        '${resultado.hour.toString().padLeft(2, '0')}:'
        '${resultado.minute.toString().padLeft(2, '0')}';

    setState(() {
      horarioSelecionado = resultado;
      horarioController.text = horarioFormatado;
    });
  }

  // Busca destinos usando o texto informado
  Future<void> buscarDestino() async {
    final textoDestino = destinoController.text.trim();

    if (textoDestino.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Digite o destino'),
        ),
      );

      return;
    }

    setState(() {
      buscandoDestino = true;
      destinoSelecionado = null;
    });

    // Busca enderecos em qualquer cidade do Brasil
    final opcoes =
    await enderecoService.buscarLocalizacoesPorEndereco(
      textoDestino,
    );

    if (!mounted) {
      return;
    }

    setState(() {
      buscandoDestino = false;
    });

    if (opcoes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nenhum destino encontrado'),
        ),
      );

      return;
    }

    // Seleciona diretamente quando houver uma unica opcao
    if (opcoes.length == 1) {
      selecionarDestino(opcoes.first);
      return;
    }

    // Mostra todos os resultados encontrados
    final resultado =
    await showModalBottomSheet<LocalizacaoSelecionada>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: opcoes.length,
            separatorBuilder: (context, index) =>
            const Divider(),
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
        );
      },
    );

    if (!mounted || resultado == null) {
      return;
    }

    selecionarDestino(resultado);
  }

  // Guarda o destino escolhido e mostra o endereco completo
  void selecionarDestino(
      LocalizacaoSelecionada destino,
      ) {
    setState(() {
      destinoSelecionado = destino;
      destinoController.text = destino.endereco;
    });
  }

  // Marca ou desmarca um dia da semana
  void alternarDiaSemana(String dia) {
    setState(() {
      if (diasSelecionados.contains(dia)) {
        diasSelecionados.remove(dia);
      } else {
        diasSelecionados.add(dia);
      }
    });
  }

  // Ativa ou desativa a recorrencia
  void alterarRecorrencia(bool valor) {
    setState(() {
      caronaRecorrente = valor;

      // Limpa os dias quando a recorrencia for desligada
      if (!caronaRecorrente) {
        diasSelecionados.clear();
      }
    });
  }

  // Valida os dados antes de criar a oferta
  void ofertarCarona() {
    if (origemController.text.isEmpty ||
        destinoController.text.isEmpty ||
        dataController.text.isEmpty ||
        horarioController.text.isEmpty ||
        vagasController.text.isEmpty ||
        valorController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Preencha todos os campos obrigatorios',
          ),
        ),
      );

      return;
    }

    if (origemSelecionada == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Confirme a origem pelo mapa'),
        ),
      );

      return;
    }

    if (destinoSelecionado == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Busque e selecione o destino'),
        ),
      );

      return;
    }

    if (caronaRecorrente && diasSelecionados.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Selecione pelo menos um dia da semana',
          ),
        ),
      );

      return;
    }

    // Converte o valor formatado para numero
    final valor = converterMoedaRealParaDouble(
      valorController.text,
    );

    if (valor < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Informe um valor valido'),
        ),
      );

      return;
    }

    // Mensagem temporaria ate conectar esta tela ao backend
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Oferta de carona criada com sucesso',
        ),
      ),
    );
  }

  @override
  void dispose() {
    // Libera os controllers da memoria
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Ofertar carona',
                style: TextStyle(
                  color: AppColors.text,
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 8),

              const Text(
                'Informe os dados da viagem',
                style: TextStyle(
                  color: AppColors.text,
                  fontSize: 18,
                ),
              ),

              const SizedBox(height: 32),

              // Origem estimada automaticamente pelo mapa
              CampoTextoCarona(
                label: 'Origem',
                icone: Icons.my_location,
                controller: origemController,
                somenteLeitura: true,
                onTap: escolherOrigemNoMapa,
                suffixIcon: const Icon(
                  Icons.map_outlined,
                  color: AppColors.primary,
                ),
              ),

              const SizedBox(height: 16),

              // Destino digitado e buscado pelo usuario
              CampoTextoCarona(
                label: 'Destino',
                icone: Icons.location_on_outlined,
                controller: destinoController,
                suffixIcon: buscandoDestino
                    ? const Padding(
                  padding: EdgeInsets.all(12),
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                    ),
                  ),
                )
                    : IconButton(
                  onPressed: buscarDestino,
                  icon: const Icon(Icons.search),
                ),
              ),

              const SizedBox(height: 16),

              // Data escolhida pelo calendario
              CampoTextoCarona(
                label: 'Data',
                icone: Icons.calendar_today_outlined,
                controller: dataController,
                somenteLeitura: true,
                onTap: escolherData,
                suffixIcon: const Icon(
                  Icons.arrow_drop_down,
                ),
              ),

              const SizedBox(height: 16),

              // Horario escolhido pelo seletor
              CampoTextoCarona(
                label: 'Horario',
                icone: Icons.access_time,
                controller: horarioController,
                somenteLeitura: true,
                onTap: escolherHorario,
                suffixIcon: const Icon(
                  Icons.arrow_drop_down,
                ),
              ),

              const SizedBox(height: 16),

              // Quantidade de lugares disponiveis
              CampoTextoCarona(
                label: 'Quantidade de vagas',
                icone: Icons.people_outline,
                controller: vagasController,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                ],
              ),

              const SizedBox(height: 16),

              // Valor formatado automaticamente em real
              CampoTextoCarona(
                label: 'Valor por passageiro',
                icone: Icons.payments_outlined,
                controller: valorController,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FormatadorMoedaReal(),
                ],
              ),

              const SizedBox(height: 16),

              // Configuracao da repeticao da carona
              CampoRecorrenciaCarona(
                caronaRecorrente: caronaRecorrente,
                diasSelecionados: diasSelecionados,
                onRecorrenciaChanged: alterarRecorrencia,
                onDiaSelecionado: alternarDiaSemana,
              ),

              const SizedBox(height: 16),

              // Informacoes opcionais
              CampoTextoCarona(
                label: 'Observacoes',
                icone: Icons.notes,
                controller: observacoesController,
                maxLines: 3,
              ),

              const SizedBox(height: 32),

              BotaoAcaoHome(
                texto: 'OFERTAR CARONA',
                icone: Icons.groups_outlined,
                onPressed: ofertarCarona,
              ),
            ],
          ),
        ),
      ),
    );
  }
}