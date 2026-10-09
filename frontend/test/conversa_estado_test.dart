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
  test('arquiva chat de solicitacao expirada sem aguardar 24h ou horario', () {
    final agora = DateTime.utc(2026, 10, 8, 12);
    final json = conversaJson('ATIVA')..['status'] = 'EXPIRADA';
    final conversa = Conversa.fromJson(json);
    expect(conversa.encerrada, isTrue);
    expect(conversa.deveArquivar(agora), isTrue);
    json['encerradaEm'] = agora.toIso8601String();
    expect(Conversa.fromJson(json).deveArquivar(agora), isTrue);
  });

  test('arquiva imediatamente quando a propria carona esta expirada', () {
    expect(
      Conversa.fromJson(
        conversaJson('EXPIRADA'),
      ).deveArquivar(DateTime.utc(2026, 10, 8)),
      isTrue,
    );
  });

  test('arquiva somente apos 24 horas completas do encerramento', () {
    final json = conversaJson('FINALIZADA')
      ..['criadoEm'] = '2026-01-01T12:00:00Z'
      ..['encerradaEm'] = '2026-10-07T12:00:00-03:00';
    final conversa = Conversa.fromJson(json);
    expect(
      conversa.deveArquivar(DateTime.parse('2026-10-08T14:59:59Z')),
      isFalse,
    );
    expect(
      conversa.deveArquivar(DateTime.parse('2026-10-08T15:00:00Z')),
      isTrue,
    );
    expect(
      conversa.deveArquivar(DateTime.parse('2026-10-09T15:00:00Z')),
      isTrue,
    );
  });

  test('nao infere horario de encerramento pela criacao ou pela viagem', () {
    final json = conversaJson('FINALIZADA')
      ..['criadoEm'] = '2026-01-01T12:00:00Z';
    final conversa = Conversa.fromJson(json);
    expect(conversa.encerradaEm, isNull);
    expect(conversa.deveArquivar(DateTime(2026, 10, 10)), isFalse);
  });

  test('nao arquiva conversa aberta com horario antigo de encerramento', () {
    final json = conversaJson('ATIVA')
      ..['encerradaEm'] = '2026-01-01T12:00:00Z';
    expect(
      Conversa.fromJson(json).deveArquivar(DateTime(2026, 10, 10)),
      isFalse,
    );
  });

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
