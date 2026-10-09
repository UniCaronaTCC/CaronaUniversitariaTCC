import 'package:flutter/material.dart';

import '../config/app_colors.dart';
import '../mapa/widgets/mapa_rota_carona.dart';
import '../models/carona.dart';
import '../models/ponto_embarque.dart';
import '../utils/formatador_data.dart';
import 'avatar_usuario.dart';

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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AvatarUsuario(
                nome: carona.motorista,
                urlFoto: fotoMotorista,
                raio: 22,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Motorista',
                      style: TextStyle(color: Colors.black54, fontSize: 13),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      carona.motorista,
                      style: const TextStyle(
                        color: AppColors.text,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),
          Text(
            _textoStatus(),
            style: const TextStyle(
              color: Colors.black54,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Divider(height: 32),
          Wrap(
            spacing: 24,
            runSpacing: 20,
            children: [
              SizedBox(
                width: 150,
                child: _SecaoDetalhe(
                  titulo: 'Data e horário',
                  icone: Icons.access_time,
                  conteudo: '${_textoData()}\n${carona.horarioFormatado}',
                ),
              ),
              SizedBox(
                width: 150,
                child: _SecaoDetalhe(
                  titulo: 'Valor por passageiro',
                  icone: Icons.payments_outlined,
                  conteudo: carona.valorFormatado,
                ),
              ),
            ],
          ),
          const Divider(height: 32),
          if (carona.origem.trim().isNotEmpty) ...[
            _SecaoDetalhe(
              titulo: 'Origem',
              icone: Icons.trip_origin,
              conteudo: carona.origem.trim(),
            ),
            const SizedBox(height: 22),
          ],
          _SecaoPontosEmbarque(pontos: carona.pontosEmbarque),
          const SizedBox(height: 22),
          _SecaoDetalhe(
            titulo: 'Destino',
            icone: Icons.location_on_outlined,
            conteudo: carona.destino,
          ),
          const Divider(height: 32),
          if (carona.veiculoModelo?.trim().isNotEmpty == true) ...[
            _SecaoDetalhe(
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
          ],

          if (!somenteConsulta &&
              ['ATIVA', 'LOTADA'].contains(carona.status)) ...[
            const SizedBox(height: 22),
            _SecaoDetalhe(
              titulo: 'Vagas disponíveis',
              icone: Icons.people_outline,
              conteudo: '${carona.vagas} vagas',
            ),
          ],

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

          if (rodape != null) ...[const SizedBox(height: 30), rodape!],
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
          'Pontos de embarque',
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
