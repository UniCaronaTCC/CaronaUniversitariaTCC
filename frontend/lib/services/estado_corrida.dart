import 'dart:async';

import '../models/carona.dart';
import 'carona_service.dart';

class EstadoCorrida {
  final int idCarona;
  final void Function(Carona) onEncerrada;
  final Future<Map<String, dynamic>> Function(int) carregar;
  Timer? _timer;
  bool _consultando = false;
  bool _descartado = false;
  bool _encerrada = false;

  EstadoCorrida({
    required this.idCarona,
    required this.onEncerrada,
    this.carregar = CaronaService.buscarDetalhesCarona,
  });

  void iniciar() {
    if (_descartado || _encerrada || _timer != null) return;
    unawaited(consultar());
    _timer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => unawaited(consultar()),
    );
  }

  Future<void> consultar() async {
    if (_descartado || _encerrada || _consultando) return;
    _consultando = true;
    try {
      final resposta = await carregar(
        idCarona,
      ).timeout(const Duration(seconds: 10));
      final carona = resposta['dados'];
      if (!_descartado &&
          resposta['sucesso'] == true &&
          carona is Carona &&
          carona.id == idCarona &&
          carona.encerrada) {
        _encerrada = true;
        _timer?.cancel();
        onEncerrada(carona);
      }
    } catch (_) {
      // Uma falha de rede nao significa que a corrida foi encerrada.
    } finally {
      _consultando = false;
    }
  }

  void dispose() {
    _descartado = true;
    _timer?.cancel();
  }
}
