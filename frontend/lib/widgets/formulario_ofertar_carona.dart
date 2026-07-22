import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config/app_colors.dart';
import '../utils/formatador_moeda.dart';
import 'botao_acao_home.dart';
import 'campo_recorrencia_carona.dart';
import 'campo_texto_carona.dart';

// Monta somente a parte visual do formulario de oferta.
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

  final bool buscandoDestino;
  final bool caronaRecorrente;
  final bool enviandoCarona;
  final List<String> diasSelecionados;

  final VoidCallback onSelecionarOrigem;
  final VoidCallback onBuscarDestino;
  final VoidCallback onSelecionarData;
  final VoidCallback onSelecionarHorario;
  final VoidCallback onOfertarCarona;

  final ValueChanged<String> onDestinoChanged;
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
    required this.buscandoDestino,
    required this.caronaRecorrente,
    required this.diasSelecionados,
    required this.onSelecionarOrigem,
    required this.onBuscarDestino,
    required this.onSelecionarData,
    required this.onSelecionarHorario,
    required this.onOfertarCarona,
    required this.onDestinoChanged,
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
          style: const TextStyle(color: AppColors.text, fontSize: 18),
        ),
        const SizedBox(height: 32),

        // A origem vem da localizacao estimada e pode ser ajustada no mapa.
        CampoTextoCarona(
          label: 'Origem',
          icone: Icons.my_location,
          controller: origemController,
          somenteLeitura: true,
          onTap: onSelecionarOrigem,
          suffixIcon: const Icon(Icons.map_outlined, color: AppColors.primary),
        ),
        const SizedBox(height: 16),

        // O destino precisa ser digitado e confirmado pela busca.
        CampoTextoCarona(
          label: 'Destino',
          icone: Icons.location_on_outlined,
          controller: destinoController,
          keyboardType: TextInputType.streetAddress,
          onChanged: onDestinoChanged,
          suffixIcon: buscandoDestino
              ? const Padding(
                  padding: EdgeInsets.all(12),
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : IconButton(
                  tooltip: 'Buscar destino',
                  onPressed: onBuscarDestino,
                  icon: const Icon(Icons.search),
                ),
        ),
        const SizedBox(height: 16),

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
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        ),
        const SizedBox(height: 16),

        CampoTextoCarona(
          label: 'Valor por passageiro',
          icone: Icons.payments_outlined,
          controller: valorController,
          keyboardType: TextInputType.number,
          inputFormatters: [FormatadorMoedaReal()],
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
          texto: enviandoCarona ? textoCarregando : textoBotao,
          icone: enviandoCarona ? Icons.hourglass_top : Icons.groups_outlined,
          onPressed: enviandoCarona ? null : onOfertarCarona,
        ),
      ],
    );
  }
}
