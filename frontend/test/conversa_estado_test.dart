import 'package:flutter_test/flutter_test.dart';
import 'package:uni_carona/models/conversa.dart';

Map<String, dynamic> conversaJson(
  String statusCarona, {
  bool encerrada = false,
}) => {
  'id': 1,
  'status': 'ACEITA',
  'encerrada': encerrada,
  'criadoEm': '2026-10-07T12:00:00Z',
  'solicitacao': {
    'id': 10,
    'passageiro': {'id': 1, 'nome': 'Joao'},
    'motorista': {'id': 2, 'nome': 'Maria'},
    'carona': {
      'id': 20,
      'status': statusCarona,
      'destino': 'UNESP',
      'dataInicio': '2026-10-07',
      'horario': '19:00:00',
    },
  },
};

void main() {
  for (final status in ['FINALIZADA', 'CANCELADA']) {
    test('encerra carona $status sem alterar solicitacao aceita', () {
      final conversa = Conversa.fromJson(conversaJson(status));
      expect(conversa.encerrada, isTrue);
      expect(conversa.status, 'ACEITA');
    });
  }
  for (final status in ['ATIVA', 'LOTADA', 'EM_ANDAMENTO']) {
    test('mantem chat aberto para carona $status', () {
      expect(Conversa.fromJson(conversaJson(status)).encerrada, isFalse);
    });
  }
  test('respeita encerramento informado pelo servidor', () {
    expect(
      Conversa.fromJson(conversaJson('ATIVA', encerrada: true)).encerrada,
      isTrue,
    );
  });
}
