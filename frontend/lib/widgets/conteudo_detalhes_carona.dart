import 'package:flutter/material.dart';

import '../config/app_colors.dart';
import '../mapa/widgets/mapa_rota_carona.dart';
import '../models/carona.dart';
import '../models/ponto_embarque.dart';
import '../utils/formatador_data.dart';
import 'avatar_usuario.dart';
import 'visual_buscaeu.dart';

class ConteudoDetalhesCarona extends StatelessWidget {
  final Carona carona;
  final Widget? rodape;
  final bool somenteConsulta;
  final String? fotoMotorista;

  const ConteudoDetalhesCarona({
    super.key,
    required this.carona,
    this.rodape,
    this.somenteConsulta = false,
    this.fotoMotorista,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CartaoBuscaEu(
            child: Row(
              children: [
                AvatarUsuario(
                  nome: carona.motorista,
                  urlFoto: fotoMotorista ?? carona.fotoMotorista,
                  raio: 22,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Motorista', style: VisualBuscaEu.descricao),
                      const SizedBox(height: 3),
                      Text(carona.motorista, style: VisualBuscaEu.titulo),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerLeft,
            child: SeloBuscaEu(texto: _textoStatus()),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                carona.horarioFormatado,
                style: const TextStyle(
                  color: AppColors.primary,
                  fontSize: 34,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(_textoData(), style: VisualBuscaEu.descricao),
            ],
          ),
          Text(carona.rotuloHorario, style: VisualBuscaEu.descricao),
          const SizedBox(height: 16),
          CartaoBuscaEu(
            cor: AppColors.primary.withValues(alpha: .06),
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              spacing: 20,
              runSpacing: 12,
              children: [
                if (!somenteConsulta &&
                    ['ATIVA', 'LOTADA'].contains(carona.status))
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.people_outline,
                        size: 20,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${carona.vagas} ${carona.vagas == 1 ? 'vaga' : 'vagas'}',
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      carona.valorFormatado,
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Text(
                      'Valor por passageiro',
                      style: VisualBuscaEu.descricao,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Text('Percurso', style: VisualBuscaEu.titulo),
          const SizedBox(height: 12),
          CartaoBuscaEu(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (carona.pontosEmbarque.isEmpty &&
                    carona.origem.trim().isNotEmpty) ...[
                  _SecaoDetalhe(
                    titulo: 'Saída cadastrada',
                    icone: Icons.trip_origin,
                    conteudo: carona.origem.trim(),
                  ),
                  const SizedBox(height: 20),
                ],
                _SecaoPontosEmbarque(pontos: carona.pontosEmbarqueOrdenados),
                const SizedBox(height: 20),
                _SecaoDetalhe(
                  titulo: 'Destino',
                  icone: Icons.school_outlined,
                  conteudo: carona.destino,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          MapaRotaCarona(carona: carona),
          if (carona.veiculoModelo?.trim().isNotEmpty == true) ...[
            const SizedBox(height: 24),
            CartaoBuscaEu(
              child: _SecaoDetalhe(
                titulo: 'Veículo',
                icone: Icons.directions_car_outlined,
                conteudo: [
                  carona.veiculoModelo!.trim(),
                  if (carona.veiculoCor?.trim().isNotEmpty == true)
                    carona.veiculoCor!.trim(),
                  if (carona.veiculoPlaca?.trim().isNotEmpty == true)
                    carona.veiculoPlaca!.trim(),
                ].join(' • '),
              ),
            ),
          ],
          if (carona.recorrente) ...[
            const SizedBox(height: 16),
            CartaoBuscaEu(
              child: _SecaoDetalhe(
                titulo: 'Repetição',
                icone: Icons.repeat,
                conteudo: _textoRecorrencia(),
              ),
            ),
          ],
          if (carona.observacoes?.trim().isNotEmpty == true) ...[
            const SizedBox(height: 16),
            CartaoBuscaEu(
              child: _SecaoDetalhe(
                titulo: 'Observações',
                icone: Icons.notes_outlined,
                conteudo: carona.observacoes!.trim(),
              ),
            ),
          ],
          if (rodape != null) ...[const SizedBox(height: 24), rodape!],
        ],
      ),
    );
  }

  String _textoData() {
    return '${FormatadorData.completa(carona.dataInicio)}/${carona.dataInicio.year}';
  }

  String _textoStatus() {
    return switch (carona.status) {
      'ATIVA' => 'Carona agendada',
      'LOTADA' => 'Carona lotada',
      'EM_ANDAMENTO' => 'Carona em andamento',
      'FINALIZADA' => 'Carona finalizada',
      'ENCERRADA_POR_TEMPO' => 'Encerrada automaticamente por tempo',
      'CANCELADA' => 'Carona cancelada',
      'EXPIRADA' => 'Carona expirada',
      _ => 'Carona encerrada',
    };
  }

  String _textoRecorrencia() {
    final dias = carona.diasSemana.isEmpty
        ? 'Dias não informados'
        : carona.diasSemana.join(', ');

    if (carona.dataFim == null) {
      return dias;
    }

    return '$dias, até ${_formatarData(carona.dataFim!)}';
  }

  String _formatarData(DateTime data) {
    return FormatadorData.completa(data);
  }
}

class _SecaoPontosEmbarque extends StatelessWidget {
  final List<PontoEmbarque> pontos;

  const _SecaoPontosEmbarque({required this.pontos});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Pontos de encontro',
          style: TextStyle(color: Colors.black54, fontSize: 13),
        ),

        const SizedBox(height: 8),

        if (pontos.isEmpty)
          const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.location_off_outlined,
                color: AppColors.primary,
                size: 22,
              ),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Nenhum ponto de encontro cadastrado',
                  style: TextStyle(
                    color: AppColors.text,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          )
        else
          ...pontos.map(
            (ponto) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _ItemPontoEmbarque(ponto: ponto),
            ),
          ),
      ],
    );
  }
}

class _ItemPontoEmbarque extends StatelessWidget {
  final PontoEmbarque ponto;

  const _ItemPontoEmbarque({required this.ponto});

  @override
  Widget build(BuildContext context) {
    final nome = ponto.nome?.trim();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(
          Icons.person_pin_circle_outlined,
          color: AppColors.primary,
          size: 22,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Encontro ${ponto.ordem}',
                style: const TextStyle(
                  color: AppColors.primary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              if (nome != null &&
                  nome.isNotEmpty &&
                  nome.toLowerCase() !=
                      ponto.endereco.trim().toLowerCase()) ...[
                Text(
                  nome,
                  style: const TextStyle(
                    color: AppColors.text,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
              ],
              Text(
                ponto.endereco,
                style: TextStyle(
                  color: nome != null && nome.isNotEmpty
                      ? Colors.black54
                      : AppColors.text,
                  fontSize: nome != null && nome.isNotEmpty ? 14 : 16,
                  fontWeight: nome != null && nome.isNotEmpty
                      ? FontWeight.normal
                      : FontWeight.w600,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SecaoDetalhe extends StatelessWidget {
  final String titulo;
  final IconData icone;
  final String conteudo;

  const _SecaoDetalhe({
    required this.titulo,
    required this.icone,
    required this.conteudo,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          titulo,
          style: const TextStyle(color: Colors.black54, fontSize: 13),
        ),
        const SizedBox(height: 7),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icone, color: AppColors.primary, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                conteudo,
                style: const TextStyle(
                  color: AppColors.text,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  height: 1.35,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
