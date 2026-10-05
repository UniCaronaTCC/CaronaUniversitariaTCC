import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import '../../models/ponto_embarque.dart';
import '../../services/progresso_carona_service.dart';

class ProgressoCorrida extends ChangeNotifier {
  final int idCarona;
  final ProgressoCaronaService service;
  List<PontoEmbarque> pontos = [];
  bool carregado = false;
  String? erro;
  bool _ocupado = false;
  bool _descartado = false;
  int? _pendente;
  DateTime? _leituraProxima;
  Timer? _retry;

  ProgressoCorrida(this.idCarona, {ProgressoCaronaService? service})
    : service = service ?? ProgressoCaronaService();

  Set<int> get concluidos =>
      pontos.where((p) => p.percorridoEm != null).map((p) => p.id!).toSet();
  PontoEmbarque? get proximo {
    for (final ponto in pontos) {
      if (ponto.percorridoEm == null) return ponto;
    }
    return null;
  }

  bool get salvando => _pendente != null;

  Future<void> sincronizar() async {
    if (_descartado || _ocupado) return;
    _retry?.cancel();
    _ocupado = true;
    try {
      final pendente = _pendente;
      final recebidos = pendente == null
          ? await service.consultar(idCarona)
          : await service.marcar(idCarona, pendente);
      if (_descartado) return;
      pontos = recebidos..sort((a, b) => a.ordem.compareTo(b.ordem));
      carregado = true;
      _pendente = null;
      erro = null;
    } catch (e) {
      if (_descartado) return;
      erro = 'Progresso não sincronizado. Mantendo os pontos confirmados.';
      if (e is! ErroProgresso || e.temporario) {
        _retry = Timer(const Duration(seconds: 5), sincronizar);
      } else {
        _pendente = null;
      }
    } finally {
      _ocupado = false;
      if (!_descartado) notifyListeners();
    }
  }

  void observar(Position posicao) {
    if (!carregado || _pendente != null || _descartado) return;
    final ponto = proximo;
    if (ponto?.id == null) return;
    final distancia = Geolocator.distanceBetween(
      posicao.latitude,
      posicao.longitude,
      ponto!.latitude,
      ponto.longitude,
    );
    if (!posicao.accuracy.isFinite ||
        posicao.accuracy < 0 ||
        posicao.accuracy > 30 ||
        !distancia.isFinite ||
        distancia > 30) {
      _leituraProxima = null;
      return;
    }
    final anterior = _leituraProxima;
    _leituraProxima = posicao.timestamp;
    if (anterior == null) return;
    final intervalo = posicao.timestamp.difference(anterior);
    if (intervalo <= Duration.zero || intervalo > const Duration(seconds: 15)) {
      return;
    }
    marcarProximo();
  }

  void marcarProximo() {
    if (!carregado || _pendente != null || _ocupado || _descartado) return;
    final id = proximo?.id;
    if (id == null) return;
    _pendente = id;
    _leituraProxima = null;
    notifyListeners();
    unawaited(sincronizar());
  }

  @override
  void dispose() {
    _descartado = true;
    _retry?.cancel();
    super.dispose();
  }
}
