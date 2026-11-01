import 'package:flutter/material.dart';

import '../config/app_colors.dart';
import '../mapa/models/localizacao_selecionada.dart';
import '../models/ponto_embarque.dart';
import '../utils/formatador_moeda.dart';
import 'botao_acao_home.dart';
import 'campo_recorrencia_carona.dart';
import 'campo_texto_carona.dart';
import 'seletor_quantidade_passageiros.dart';
import 'campo_destino_campus.dart';
import 'visual_buscaeu.dart';
import 'pontos_encontro_oferta.dart';

class FormularioOfertarCarona extends StatelessWidget {
  final String titulo;
  final String descricao;
  final String textoBotao;
  final String textoCarregando;

  final TextEditingController destinoController;
  final TextEditingController dataController;
  final TextEditingController horarioController;
  final TextEditingController vagasController;
  final int? passageirosAceitos;
  final int capacidadeMinima;
  final TextEditingController valorController;
  final TextEditingController observacoesController;

  final bool caronaRecorrente;
  final bool enviandoCarona;
  final bool pontosEmbarqueEditaveis;
  final bool possuiVeiculo;
  final bool mostrarRecorrencia;
  final bool mostrarTitulo;

  final List<String> diasSelecionados;
  final List<PontoEmbarque> pontosEmbarque;
  final LocalizacaoSelecionada? referenciaDestino;
  final VoidCallback onSelecionarDestino;
  final VoidCallback onSelecionarData;
  final VoidCallback onSelecionarHorario;
  final VoidCallback onAdicionarPontoEmbarque;
  final VoidCallback onOfertarCarona;
  final VoidCallback onCadastrarVeiculo;

  final ValueChanged<int> onRemoverPontoEmbarque;
  final ValueChanged<String> onDestinoChanged;
  final ValueChanged<LocalizacaoSelecionada> onDestinoSelecionado;
  final ValueChanged<bool> onRecorrenciaChanged;
  final ValueChanged<String> onDiaSelecionado;

  const FormularioOfertarCarona({
    super.key,
    this.titulo = 'Ofertar carona',
    this.descricao = 'Informe os dados da viagem',
    this.textoBotao = 'OFERTAR CARONA',
    this.textoCarregando = 'ENVIANDO...',
    this.mostrarRecorrencia = true,
    this.mostrarTitulo = true,
    required this.destinoController,
    required this.dataController,
    required this.horarioController,
    required this.vagasController,
    this.passageirosAceitos,
    this.capacidadeMinima = 1,
    required this.valorController,
    required this.observacoesController,
    required this.caronaRecorrente,
    required this.diasSelecionados,
    required this.pontosEmbarque,
    this.referenciaDestino,
    required this.pontosEmbarqueEditaveis,
    required this.possuiVeiculo,
    required this.onSelecionarDestino,
    required this.onSelecionarData,
    required this.onSelecionarHorario,
    required this.onAdicionarPontoEmbarque,
    required this.onRemoverPontoEmbarque,
    required this.onOfertarCarona,
    required this.onCadastrarVeiculo,
    required this.onDestinoChanged,
    required this.onDestinoSelecionado,
    required this.onRecorrenciaChanged,
    required this.onDiaSelecionado,
    required this.enviandoCarona,
  });

  bool get edicaoLimitada => (passageirosAceitos ?? 0) > 0;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (mostrarTitulo)
          Text(
            titulo,
            style: const TextStyle(
              color: AppColors.text,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),

        const SizedBox(height: 8),

        Text(descricao, style: VisualBuscaEu.descricao),

        const SizedBox(height: 24),

        if (!possuiVeiculo) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.orange.withValues(alpha: 0.35)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.directions_car_outlined, color: Colors.orange),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Cadastre seu veículo antes de oferecer uma carona.',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: onCadastrarVeiculo,
                  child: const Text('CADASTRAR NO PERFIL'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],

        // O destino pode ser pesquisado ou marcado direto no mapa.
        if (edicaoLimitada)
          CampoTextoCarona(
            visualAtualizado: true,
            label: 'Destino',
            icone: Icons.place_outlined,
            controller: destinoController,
            somenteLeitura: true,
            suffixIcon: const Icon(Icons.lock_outline),
          )
        else
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: CampoDestinoCampus(
                  visualAtualizado: true,
                  controller: destinoController,
                  onChanged: onDestinoChanged,
                  onSelecionado: onDestinoSelecionado,
                  referenciaInicial: referenciaDestino,
                ),
              ),

              const SizedBox(width: 8),

              IconButton(
                tooltip: 'Escolher destino no mapa',
                onPressed: onSelecionarDestino,
                icon: const Icon(Icons.map_outlined, color: AppColors.primary),
              ),
            ],
          ),

        const SizedBox(height: 24),

        PontosEncontroOferta(
          pontos: pontosEmbarque,
          editaveis: pontosEmbarqueEditaveis,
          edicaoLimitada: edicaoLimitada,
          onAdicionar: onAdicionarPontoEmbarque,
          onRemover: onRemoverPontoEmbarque,
        ),

        const SizedBox(height: 24),

        CamposLadoALado(
          primeiro: CampoTextoCarona(
            visualAtualizado: true,
            label: caronaRecorrente ? 'Repetir a partir de' : 'Data',
            icone: Icons.calendar_today_outlined,
            controller: dataController,
            somenteLeitura: true,
            onTap: edicaoLimitada ? null : onSelecionarData,
            suffixIcon: Icon(
              edicaoLimitada ? Icons.lock_outline : Icons.arrow_drop_down,
            ),
          ),
          segundo: CampoTextoCarona(
            visualAtualizado: true,
            label: 'Horário do primeiro encontro',
            icone: Icons.access_time,
            controller: horarioController,
            somenteLeitura: true,
            onTap: edicaoLimitada ? null : onSelecionarHorario,
            suffixIcon: Icon(
              edicaoLimitada ? Icons.lock_outline : Icons.arrow_drop_down,
            ),
          ),
        ),

        const SizedBox(height: 16),

        SeletorQuantidadePassageiros(
          controller: vagasController,
          passageirosAceitos: passageirosAceitos,
          capacidadeMinima: capacidadeMinima,
        ),

        const SizedBox(height: 16),

        CampoTextoCarona(
          visualAtualizado: true,
          label: 'Valor por passageiro',
          icone: Icons.payments_outlined,
          controller: valorController,
          somenteLeitura: edicaoLimitada,
          suffixIcon: edicaoLimitada ? const Icon(Icons.lock_outline) : null,
          keyboardType: TextInputType.number,
          inputFormatters: [FormatadorMoedaReal()],
        ),

        const SizedBox(height: 16),

        if (mostrarRecorrencia && !edicaoLimitada)
          CampoRecorrenciaCarona(
            caronaRecorrente: caronaRecorrente,
            diasSelecionados: diasSelecionados,
            onRecorrenciaChanged: onRecorrenciaChanged,
            onDiaSelecionado: onDiaSelecionado,
          ),

        const SizedBox(height: 16),

        CampoTextoCarona(
          visualAtualizado: true,
          label: 'Observações',
          icone: Icons.notes,
          controller: observacoesController,
          maxLines: 3,
        ),

        const SizedBox(height: 32),

        BotaoAcaoHome(
          estilo: EstiloBotaoAcaoHome.principal,
          carregando: enviandoCarona,
          texto: enviandoCarona ? textoCarregando : textoBotao,
          icone: enviandoCarona ? Icons.hourglass_top : Icons.groups_outlined,
          onPressed: enviandoCarona || !possuiVeiculo ? null : onOfertarCarona,
        ),
      ],
    );
  }
}
