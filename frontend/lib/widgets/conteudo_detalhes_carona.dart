import 'package:flutter/material.dart';

import '../config/app_colors.dart';
import '../mapa/widgets/mapa_rota_carona.dart';
import '../models/carona.dart';
import '../models/ponto_embarque.dart';
import '../utils/formatador_data.dart';

class ConteudoDetalhesCarona extends StatelessWidget {
  final Carona carona;
  final Widget? rodape;

  const ConteudoDetalhesCarona({
    super.key,
    required this.carona,
    this.rodape,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.directions_car_outlined,
                color: AppColors.primary,
                size: 30,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  carona.motorista,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.text,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Text(
                carona.valorFormatado,
                style: const TextStyle(
                  color: AppColors.primary,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),

          if (carona.status != 'ATIVA') ...[
            const SizedBox(height: 12),
            Text(
              carona.status,
              style: const TextStyle(
                color: Colors.black54,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],

          const SizedBox(height: 32),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.access_time,
                  color: AppColors.primary,
                  size: 34,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        carona.horarioFormatado,
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _textoData(),
                        style: const TextStyle(
                          color: AppColors.text,
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 30),

          _SecaoDetalhe(
            titulo: 'Destino',
            icone: Icons.location_on_outlined,
            conteudo: carona.destino,
          ),

          if (carona.origem.trim().isNotEmpty) ...[
            const SizedBox(height: 22),
            _SecaoDetalhe(
              titulo: 'Origem',
              icone: Icons.trip_origin,
              conteudo: carona.origem.trim(),
            ),
          ],

          const SizedBox(height: 22),

          _SecaoPontosEmbarque(
            pontos: carona.pontosEmbarque,
          ),

          const SizedBox(height: 22),

          _SecaoDetalhe(
            titulo: 'Vagas disponíveis',
            icone: Icons.people_outline,
            conteudo: '${carona.vagas} vagas',
          ),

          if (carona.recorrente) ...[
            const SizedBox(height: 22),
            _SecaoDetalhe(
              titulo: 'Repetição',
              icone: Icons.repeat,
              conteudo: _textoRecorrencia(),
            ),
          ],

          if (carona.observacoes?.trim().isNotEmpty == true) ...[
            const SizedBox(height: 22),
            _SecaoDetalhe(
              titulo: 'Observações',
              icone: Icons.notes_outlined,
              conteudo: carona.observacoes!.trim(),
            ),
          ],

          const SizedBox(height: 30),
          MapaRotaCarona(carona: carona),

          if (rodape != null) ...[
            const SizedBox(height: 30),
            rodape!,
          ],
        ],
      ),
    );
  }

  String _textoData() {
    if (carona.recorrente && carona.diasSemana.isNotEmpty) {
      return carona.diasSemana.join(', ');
    }

    return carona.dataFormatada;
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

  const _SecaoPontosEmbarque({
    required this.pontos,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Pontos de embarque',
          style: TextStyle(
            color: Colors.black54,
            fontSize: 13,
          ),
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
                  'Nenhum ponto de embarque cadastrado',
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
              child: _ItemPontoEmbarque(
                ponto: ponto,
              ),
            ),
          ),
      ],
    );
  }
}

class _ItemPontoEmbarque extends StatelessWidget {
  final PontoEmbarque ponto;

  const _ItemPontoEmbarque({
    required this.ponto,
  });

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
              if (nome != null && nome.isNotEmpty) ...[
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
                  fontSize: nome != null && nome.isNotEmpty
                      ? 14
                      : 16,
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
          style: const TextStyle(
            color: Colors.black54,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 7),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              icone,
              color: AppColors.primary,
              size: 22,
            ),
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
