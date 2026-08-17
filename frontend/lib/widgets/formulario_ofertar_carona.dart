import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config/app_colors.dart';
import '../mapa/models/localizacao_selecionada.dart';
import '../mapa/widgets/barra_pesquisa_endereco.dart';
import '../models/ponto_embarque.dart';
import '../utils/formatador_moeda.dart';
import 'botao_acao_home.dart';
import 'campo_recorrencia_carona.dart';
import 'campo_texto_carona.dart';

class FormularioOfertarCarona extends StatelessWidget {
  final String titulo;
  final String descricao;
  final String textoBotao;
  final String textoCarregando;

  final TextEditingController origemController;
  final TextEditingController destinoController;
  final TextEditingController dataController;
  final TextEditingController horarioController;
  final TextEditingController vagasController;
  final TextEditingController valorController;
  final TextEditingController observacoesController;

  final bool caronaRecorrente;
  final bool enviandoCarona;
  final bool pontosEmbarqueEditaveis;

  final List<String> diasSelecionados;
  final List<PontoEmbarque> pontosEmbarque;

  final VoidCallback onSelecionarOrigem;
  final VoidCallback onSelecionarDestino;
  final VoidCallback onSelecionarData;
  final VoidCallback onSelecionarHorario;
  final VoidCallback onAdicionarPontoEmbarque;
  final VoidCallback onOfertarCarona;

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
    required this.origemController,
    required this.destinoController,
    required this.dataController,
    required this.horarioController,
    required this.vagasController,
    required this.valorController,
    required this.observacoesController,
    required this.caronaRecorrente,
    required this.diasSelecionados,
    required this.pontosEmbarque,
    required this.pontosEmbarqueEditaveis,
    required this.onSelecionarOrigem,
    required this.onSelecionarDestino,
    required this.onSelecionarData,
    required this.onSelecionarHorario,
    required this.onAdicionarPontoEmbarque,
    required this.onRemoverPontoEmbarque,
    required this.onOfertarCarona,
    required this.onDestinoChanged,
    required this.onDestinoSelecionado,
    required this.onRecorrenciaChanged,
    required this.onDiaSelecionado,
    required this.enviandoCarona,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          titulo,
          style: const TextStyle(
            color: AppColors.text,
            fontSize: 30,
            fontWeight: FontWeight.bold,
          ),
        ),

        const SizedBox(height: 8),

        Text(
          descricao,
          style: const TextStyle(
            color: AppColors.text,
            fontSize: 18,
          ),
        ),

        const SizedBox(height: 32),

        // A origem pode ser ajustada no mapa.
        CampoTextoCarona(
          label: 'Origem',
          icone: Icons.my_location,
          controller: origemController,
          somenteLeitura: true,
          onTap: onSelecionarOrigem,
          suffixIcon: const Icon(
            Icons.map_outlined,
            color: AppColors.primary,
          ),
        ),

        const SizedBox(height: 16),

        // O destino pode ser pesquisado ou marcado direto no mapa.
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: BarraPesquisaEndereco(
                label: 'Destino',
                icone: Icons.location_on_outlined,
                controller: destinoController,
                onChanged: onDestinoChanged,
                onSelecionado: onDestinoSelecionado,
                padding: EdgeInsets.zero,
                elevacao: 0,
                borderRadius: 16,
                usarLabelComoHint: false,
              ),
            ),

            const SizedBox(width: 8),

            IconButton(
              onPressed: onSelecionarDestino,
              icon: const Icon(
                Icons.map_outlined,
                color: AppColors.primary,
              ),
            ),
          ],
        ),

        const SizedBox(height: 24),

        _secaoPontosEmbarque(),

        const SizedBox(height: 24),

        CampoTextoCarona(
          label: 'Data',
          icone: Icons.calendar_today_outlined,
          controller: dataController,
          somenteLeitura: true,
          onTap: onSelecionarData,
          suffixIcon: const Icon(Icons.arrow_drop_down),
        ),

        const SizedBox(height: 16),

        CampoTextoCarona(
          label: 'Horário',
          icone: Icons.access_time,
          controller: horarioController,
          somenteLeitura: true,
          onTap: onSelecionarHorario,
          suffixIcon: const Icon(Icons.arrow_drop_down),
        ),

        const SizedBox(height: 16),

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

        CampoRecorrenciaCarona(
          caronaRecorrente: caronaRecorrente,
          diasSelecionados: diasSelecionados,
          onRecorrenciaChanged: onRecorrenciaChanged,
          onDiaSelecionado: onDiaSelecionado,
        ),

        const SizedBox(height: 16),

        CampoTextoCarona(
          label: 'Observações',
          icone: Icons.notes,
          controller: observacoesController,
          maxLines: 3,
        ),

        const SizedBox(height: 32),

        BotaoAcaoHome(
          texto: enviandoCarona
              ? textoCarregando
              : textoBotao,
          icone: enviandoCarona
              ? Icons.hourglass_top
              : Icons.groups_outlined,
          onPressed: enviandoCarona
              ? null
              : onOfertarCarona,
        ),
      ],
    );
  }

  Widget _secaoPontosEmbarque() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Pontos de embarque',
          style: TextStyle(
            color: AppColors.text,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),

        const SizedBox(height: 6),

        const Text(
          'Adicione os locais onde os passageiros poderão embarcar.',
          style: TextStyle(
            color: Colors.black54,
            fontSize: 14,
          ),
        ),

        const SizedBox(height: 14),

        if (pontosEmbarque.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(
                alpha: 0.06,
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.primary.withValues(
                  alpha: 0.20,
                ),
              ),
            ),
            child: const Row(
              children: [
                Icon(
                  Icons.location_off_outlined,
                  color: Colors.black45,
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Nenhum ponto de embarque adicionado.',
                    style: TextStyle(
                      color: Colors.black54,
                    ),
                  ),
                ),
              ],
            ),
          )
        else
          ...List.generate(
            pontosEmbarque.length,
                (indice) {
              final ponto = pontosEmbarque[indice];

              final nome = ponto.nome?.trim();

              return Padding(
                padding: const EdgeInsets.only(
                  bottom: 10,
                ),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(
                    14,
                    12,
                    8,
                    12,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(
                      alpha: 0.06,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.primary.withValues(
                        alpha: 0.18,
                      ),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment:
                    CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(
                            alpha: 0.12,
                          ),
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '${indice + 1}',
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),

                      const SizedBox(width: 12),

                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                          CrossAxisAlignment.start,
                          children: [
                            Text(
                              nome != null &&
                                  nome.isNotEmpty
                                  ? nome
                                  : 'Ponto de embarque ${indice + 1}',
                              style: const TextStyle(
                                color: AppColors.text,
                                fontSize: 15,
                                fontWeight:
                                FontWeight.w600,
                              ),
                            ),

                            const SizedBox(height: 4),

                            Text(
                              ponto.endereco,
                              style: const TextStyle(
                                color: Colors.black54,
                                fontSize: 13,
                                height: 1.3,
                              ),
                            ),
                          ],
                        ),
                      ),

                      if (pontosEmbarqueEditaveis)
                        IconButton(
                          tooltip: 'Remover ponto',
                          onPressed: () =>
                              onRemoverPontoEmbarque(
                                indice,
                              ),
                          icon: const Icon(
                            Icons.delete_outline,
                            color: Colors.redAccent,
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),

        const SizedBox(height: 4),

        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: pontosEmbarqueEditaveis
                ? onAdicionarPontoEmbarque
                : null,
            icon: const Icon(
              Icons.add_location_alt_outlined,
            ),
            label: const Text(
              'ADICIONAR PONTO DE EMBARQUE',
            ),
          ),
        ),

        if (!pontosEmbarqueEditaveis) ...[
          const SizedBox(height: 8),
          const Text(
            'A edição dos pontos de embarque será adicionada depois.',
            style: TextStyle(
              color: Colors.black45,
              fontSize: 12,
            ),
          ),
        ],
      ],
    );
  }
}