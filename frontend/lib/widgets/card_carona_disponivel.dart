import 'package:flutter/material.dart';

import '../config/app_colors.dart';
import '../models/carona.dart';

class CardCaronaDisponivel extends StatelessWidget {
  final Carona carona;
  final VoidCallback? onTap;
  final Widget? acaoCabecalho;
  final bool mostrarRecorrencia;
  final bool visualHome;

  const CardCaronaDisponivel({
    super.key,
    required this.carona,
    this.onTap,
    this.acaoCabecalho,
    this.mostrarRecorrencia = false,
    this.visualHome = false,
  });

  @override
  Widget build(BuildContext context) {
    if (visualHome) return _cardHome();
    return Material(
      key: ValueKey('card-carona-${carona.id}'),
      color: carona.finalizada ? const Color(0xFFF1F1F1) : Colors.white,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Motorista e valor.
              Row(
                children: [
                  const Icon(
                    Icons.directions_car_outlined,
                    color: AppColors.primary,
                    size: 26,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      carona.motorista,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.text,
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Text(
                    carona.valorFormatado,
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (acaoCabecalho != null) ...[
                    const SizedBox(width: 4),
                    acaoCabecalho!,
                  ],
                ],
              ),

              const SizedBox(height: 20),

              Text(
                carona.rotuloHorario,
                style: const TextStyle(color: Colors.black54, fontSize: 12),
              ),
              const SizedBox(height: 5),

              // Horario recebe o maior destaque do card.
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 14,
                runSpacing: 8,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.access_time,
                        color: AppColors.primary,
                        size: 28,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        carona.horarioFormatado,
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    _textoData(),
                    style: const TextStyle(
                      color: Colors.black54,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),

              if (mostrarRecorrencia && _diasRecorrencia.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  'Recorrência: ${_diasRecorrencia.join(', ').toLowerCase()}',
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 13,
                  ),
                ),
              ],
              const SizedBox(height: 18),

              // Destino principal da carona.
              const Text(
                'Destino',
                style: TextStyle(color: Colors.black54, fontSize: 13),
              ),
              const SizedBox(height: 5),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.location_on_outlined,
                    color: AppColors.primary,
                    size: 21,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      carona.destino,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.text,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.person_pin_circle_outlined,
                    color: Colors.black45,
                    size: 17,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      carona.resumoInicio,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.black54,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),

              const Divider(height: 28),

              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 12,
                runSpacing: 8,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.people_outline,
                        color: Colors.black54,
                        size: 19,
                      ),
                      const SizedBox(width: 7),
                      Text(
                        '${carona.vagas} vagas',
                        style: const TextStyle(
                          color: Colors.black54,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (carona.status != 'ATIVA') ...[
                        Text(
                          carona.status,
                          style: const TextStyle(
                            color: Colors.black54,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      if (onTap != null)
                        const Icon(
                          Icons.chevron_right,
                          color: AppColors.primary,
                        ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _cardHome() {
    final nome = carona.motorista.trim();
    final veiculo = [
      carona.veiculoModelo?.trim() ?? '',
      carona.veiculoCor?.trim() ?? '',
    ].where((parte) => parte.isNotEmpty).join(' • ');
    final vagas = carona.vagas == 0
        ? 'Sem vagas disponíveis'
        : carona.vagas == 1
        ? '1 vaga disponível'
        : '${carona.vagas} vagas disponíveis';

    return Material(
      key: ValueKey('card-carona-${carona.id}'),
      color: carona.finalizada ? const Color(0xFFF1F1F1) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: Color(0xFFE2E2E8)),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                spacing: 16,
                runSpacing: 12,
                children: [
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${_textoData()}, ${carona.horarioFormatado}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.text,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        carona.rotuloHorario,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.black54,
                        ),
                      ),
                    ],
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        carona.valorFormatado,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.text,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'por pessoa',
                        style: TextStyle(fontSize: 12, color: Colors.black54),
                      ),
                    ],
                  ),
                  ?acaoCabecalho,
                ],
              ),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ExcludeSemantics(
                    child: CircleAvatar(
                      radius: 18,
                      backgroundColor: AppColors.primary.withValues(
                        alpha: 0.08,
                      ),
                      child: nome.isEmpty
                          ? const Icon(
                              Icons.person_outline,
                              color: Colors.black54,
                              size: 20,
                            )
                          : Text(
                              nome.characters.first.toUpperCase(),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          nome.isEmpty ? 'Motorista' : nome,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.text,
                          ),
                        ),
                        if (veiculo.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            veiculo,
                            style: const TextStyle(
                              fontSize: 13,
                              color: Colors.black54,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _localHome(
                Icons.location_on_rounded,
                carona.resumoInicio,
                conectarAoDestino: true,
              ),
              _localHome(
                Icons.school_outlined,
                carona.destino.trim().isEmpty
                    ? 'Destino não informado'
                    : carona.destino,
              ),
              if (mostrarRecorrencia && _diasRecorrencia.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  'Recorrência: ${_diasRecorrencia.join(', ').toLowerCase()}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.primary,
                  ),
                ),
              ],
              const Divider(height: 24, color: Color(0xFFE2E2E8)),
              Row(
                children: [
                  const Icon(
                    Icons.event_seat_outlined,
                    size: 20,
                    color: Colors.black54,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      vagas,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.black54,
                      ),
                    ),
                  ),
                  if (onTap != null) ...[
                    const SizedBox(width: 8),
                    const Icon(Icons.chevron_right, color: Colors.black54),
                  ],
                ],
              ),
              if (carona.status != 'ATIVA') ...[
                const SizedBox(height: 8),
                Text(
                  carona.status,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.black54,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _localHome(
    IconData icone,
    String texto, {
    bool conectarAoDestino = false,
  }) {
    final marcador = Icon(icone, size: 20, color: AppColors.primary);
    final linha = Row(
      crossAxisAlignment: conectarAoDestino
          ? CrossAxisAlignment.stretch
          : CrossAxisAlignment.start,
      children: [
        if (conectarAoDestino)
          SizedBox(
            width: 20,
            child: Column(
              children: [
                marcador,
                const SizedBox(height: 4),
                const Expanded(
                  child: ExcludeSemantics(
                    child: CustomPaint(
                      key: ValueKey('linha-trajeto-home'),
                      size: Size(1, 0),
                      painter: _LinhaTrajetoPainter(),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
              ],
            ),
          )
        else
          marcador,
        const SizedBox(width: 10),
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(bottom: conectarAoDestino ? 16 : 0),
            child: Text(
              texto,
              style: const TextStyle(fontSize: 14, color: AppColors.text),
            ),
          ),
        ),
      ],
    );
    return conectarAoDestino ? IntrinsicHeight(child: linha) : linha;
  }

  List<String> get _diasRecorrencia {
    final dias = carona.idRecorrencia != null
        ? carona.diasRecorrencia
        : carona.recorrente
        ? carona.diasSemana
        : <String>[];
    return [
      'SEG',
      'TER',
      'QUA',
      'QUI',
      'SEX',
      'SAB',
      'DOM',
    ].where(dias.contains).toList();
  }

  String _textoData() {
    if (carona.recorrente && carona.diasSemana.isNotEmpty) {
      return carona.diasSemana.join(', ');
    }

    return carona.dataFormatada;
  }
}

class _LinhaTrajetoPainter extends CustomPainter {
  const _LinhaTrajetoPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final tinta = Paint()
      ..color = const Color(0xFF9E9EA9)
      ..strokeWidth = 1;
    for (var y = 0.0; y < size.height; y += 6) {
      canvas.drawLine(
        Offset(size.width / 2, y),
        Offset(size.width / 2, (y + 3).clamp(0, size.height)),
        tinta,
      );
    }
  }

  @override
  bool shouldRepaint(_LinhaTrajetoPainter oldDelegate) => false;
}
