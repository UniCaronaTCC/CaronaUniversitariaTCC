import 'package:flutter_test/flutter_test.dart';
import 'package:uni_carona/models/conversa.dart';

void main() {
  test('converte conversa e identifica o outro participante', () {
    final conversa = Conversa.fromJson({
      'id': 4,
      'status': 'ACEITA',
      'criadoEm': '2026-09-01T12:00:00.000Z',
      'solicitacao': {
        'id': 10,
        'passageiro': {'id': 1, 'nome': 'João'},
        'motorista': {'id': 2, 'nome': 'Maria'},
        'carona': {
          'id': 20,
          'destino': 'UniSalesiano',
          'dataInicio': '2026-09-02',
          'horario': '19:00:00',
        },
      },
      'ultimaMensagem': {
        'id': 5,
        'conteudo': 'Até amanhã!',
        'criadoEm': '2026-09-01T12:10:00.000Z',
        'remetente': {'id': 2},
      },
    });

    expect(conversa.nomeOutroParticipante(1), 'Maria');
    expect(conversa.nomeOutroParticipante(2), 'João');
    expect(conversa.ultimaMensagem?.conteudo, 'Até amanhã!');
    expect(conversa.encerrada, isFalse);
  });

  test('marca conversa cancelada como encerrada', () {
    final conversa = Conversa.fromJson({
      'id': 4,
      'status': 'CANCELADA_PASSAGEIRO',
      'criadoEm': '2026-09-01T12:00:00.000Z',
      'solicitacao': {
        'id': 10,
        'passageiro': {'id': 1, 'nome': 'João'},
        'motorista': {'id': 2, 'nome': 'Maria'},
        'carona': {
          'id': 20,
          'destino': 'UniSalesiano',
          'dataInicio': '2026-09-02',
          'horario': '19:00:00',
        },
      },
      'ultimaMensagem': null,
    });

    expect(conversa.encerrada, isTrue);
  });
}
