import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../../config/app_colors.dart';
import '../../models/carona.dart';
import '../services/rota_service.dart';
import '../utils/rota_mapa_utils.dart';
import 'mapa_percurso.dart';

class MapaRotaCarona extends StatefulWidget {
  final Carona carona;
  final double alturaMapa;

  const MapaRotaCarona({
    super.key,
    required this.carona,
    this.alturaMapa = 260,
  });

  @override
  State<MapaRotaCarona> createState() => _MapaRotaCaronaState();
}

class _MapaRotaCaronaState extends State<MapaRotaCarona> {
  final _service = RotaService();
  List<LatLng>? _paradas;
  RotaResultado? _rota;
  String? _erro;
  bool _carregando = false;
  int _requisicao = 0;

  @override
  void initState() {
    super.initState();
    _paradas = paradasDaCarona(widget.carona);
    _carregarRota();
  }

  @override
  void didUpdateWidget(covariant MapaRotaCarona oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.carona != widget.carona) {
      _paradas = paradasDaCarona(widget.carona);
      _carregarRota();
    }
  }

  Future<void> _carregarRota() async {
    final paradas = _paradas;
    final requisicao = ++_requisicao;
    setState(() {
      _erro = null;
      _carregando = paradas != null;
    });
    if (paradas == null) return;

    try {
      final rota = await _service
          .calcularRota(paradas)
          .timeout(const Duration(seconds: 40));
      if (!_rotaValida(rota)) throw const FormatException('Rota inválida');
      if (!mounted || requisicao != _requisicao) return;
      setState(() {
        _rota = rota;
        _carregando = false;
      });
    } catch (_) {
      if (!mounted || requisicao != _requisicao) return;
      setState(() {
        _carregando = false;
        _erro = 'Não foi possível carregar a rota. Tente novamente.';
      });
    }
  }

  bool _rotaValida(RotaResultado rota) {
    return rota.pontos.length >= 2 &&
        rota.pontos.every((p) => coordenadaValida(p.latitude, p.longitude)) &&
        rota.distanciaMetros.isFinite &&
        rota.distanciaMetros >= 0 &&
        rota.duracaoSegundos.isFinite &&
        rota.duracaoSegundos >= 0;
  }

  @override
  Widget build(BuildContext context) {
    final rota = _rota;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(Icons.route, color: AppColors.primary),
                SizedBox(width: 10),
                Text(
                  'Percurso da carona',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          if (_carregando && rota == null)
            const _CarregandoRota()
          else if (_paradas == null || (_erro != null && rota == null))
            _ErroRota(
              mensagem:
                  _erro ??
                  'Esta carona não possui todas as coordenadas necessárias para mostrar o percurso.',
              onTentarNovamente: _erro == null ? null : _carregarRota,
            )
          else if (rota != null) ...[
            SizedBox(
              height: widget.alturaMapa,
              child: MapaPercurso(
                carona: widget.carona,
                rota: rota,
                paradas: _paradas!,
                atualizando: _carregando,
                erroAtualizacao: _erro,
                onTentarNovamente: _carregarRota,
              ),
            ),
            _ResumoRota(rota: rota, quantidadeParadas: _paradas!.length),
          ],
        ],
      ),
    );
  }
}

class _CarregandoRota extends StatelessWidget {
  const _CarregandoRota();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(28),
      child: Column(
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Calculando o percurso pelas ruas...'),
        ],
      ),
    );
  }
}

class _ErroRota extends StatelessWidget {
  final String mensagem;
  final VoidCallback? onTentarNovamente;

  const _ErroRota({required this.mensagem, this.onTentarNovamente});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        children: [
          const Icon(Icons.map_outlined, color: Colors.black45, size: 36),
          const SizedBox(height: 10),
          Text(mensagem, textAlign: TextAlign.center),
          if (onTentarNovamente != null)
            TextButton.icon(
              onPressed: onTentarNovamente,
              icon: const Icon(Icons.refresh),
              label: const Text('Tentar novamente'),
            ),
        ],
      ),
    );
  }
}

class _ResumoRota extends StatelessWidget {
  final RotaResultado rota;
  final int quantidadeParadas;

  const _ResumoRota({required this.rota, required this.quantidadeParadas});

  @override
  Widget build(BuildContext context) {
    final distancia = (rota.distanciaMetros / 1000)
        .toStringAsFixed(1)
        .replaceAll('.', ',');
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 20,
            runSpacing: 8,
            children: [
              Text(
                '$distancia km',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                duracaoFormatada(rota.duracaoSegundos),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Distância total • Tempo estimado',
            style: TextStyle(color: Colors.black54, fontSize: 12),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 12,
            runSpacing: 6,
            children: [
              Text('● Origem', style: TextStyle(color: Colors.green.shade700)),
              if (quantidadeParadas > 2)
                Text(
                  '● Embarques numerados',
                  style: TextStyle(color: Colors.blue.shade700),
                ),
              const Text(
                '⚑ Destino',
                style: TextStyle(color: AppColors.primary),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
