import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import 'localizacao_service.dart';

/// Mantém a leitura do GPS em primeiro plano, inclusive após leituras ruins.
class RastreamentoGps extends ChangeNotifier {
  final LocalizacaoService service;
  final ValueChanged<Position> onPosicao;
  final _filtro = FiltroLocalizacaoGps();
  StreamSubscription<Position>? _subscription;
  Timer? _espera;
  bool _descartado = false;
  bool _iniciando = false;
  DateTime? _ultimaLeitura;
  String mensagem = 'Obtendo sua localização...';
  bool precisaAtencao = false;

  RastreamentoGps({required this.onPosicao, LocalizacaoService? service})
    : service = service ?? LocalizacaoService();

  Future<void> iniciar() async {
    if (_descartado || _iniciando) return;
    _iniciando = true;
    _espera?.cancel();
    _status('Obtendo sua localização...', false);
    try {
      await _subscription?.cancel();
      final stream = await service.acompanharLocalizacao();
      if (_descartado) return;
      _subscription = stream.listen(
        _receber,
        onError: (Object erro) {
          _espera?.cancel();
          _status(erro.toString().replaceFirst('Exception: ', ''), true);
        },
        onDone: () {
          _espera?.cancel();
          _status('GPS interrompido. Tente novamente.', true);
        },
      );
      _aguardarLeitura();
    } catch (erro) {
      _status(erro.toString().replaceFirst('Exception: ', ''), true);
    } finally {
      _iniciando = false;
    }
  }

  void _receber(Position posicao) {
    if (_descartado) return;
    final antiga =
        DateTime.now().difference(posicao.timestamp) >
        const Duration(seconds: 20);
    if (antiga ||
        (_ultimaLeitura != null &&
            !posicao.timestamp.isAfter(_ultimaLeitura!))) {
      return;
    }
    if (!_filtro.aceitar(
      latitude: posicao.latitude,
      longitude: posicao.longitude,
      precisao: posicao.accuracy,
    )) {
      _status('GPS impreciso. Aguardando uma posição confiável.', true);
      return;
    }
    _ultimaLeitura = posicao.timestamp;
    _aguardarLeitura();
    _status('GPS atualizado. Siga o percurso até o destino.', false);
    onPosicao(posicao);
  }

  void _aguardarLeitura() {
    _espera?.cancel();
    _espera = Timer(const Duration(seconds: 20), () {
      _status('Sem leitura recente do GPS. Mantendo a última posição.', true);
    });
  }

  void _status(String texto, bool atencao) {
    if (_descartado) return;
    mensagem = texto;
    precisaAtencao = atencao;
    notifyListeners();
  }

  @override
  void dispose() {
    _descartado = true;
    _espera?.cancel();
    _subscription?.cancel();
    super.dispose();
  }
}
