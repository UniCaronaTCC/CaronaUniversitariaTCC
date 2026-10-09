import 'package:flutter_test/flutter_test.dart';
import 'package:uni_carona/models/solicitacao_enviada.dart';
import 'package:uni_carona/models/solicitacao_recebida.dart';
import 'package:uni_carona/services/solicitacao_service.dart';

void main() {
  Map<String, dynamic> dados(String status, String statusCarona) => {
    'id': 1,
    'status': status,
    'localEmbarque': 'Centro',
    'embarqueLatitude': -21.2,
    'embarqueLongitude': -50.4,
    'motorista': {'nome': 'Motorista'},
    'passageiro': {'nome': 'Passageiro'},
    'carona': {
      'id': 2,
      'status': statusCarona,
      'destino': 'Campus',
      'dataInicio': '2026-10-20',
      'horario': '19:00:00',
      'valor': 10,
    },
  };

  for (final caso in [
    ('EXPIRADA', 'ATIVA'),
    ('EXPIRADA', 'FINALIZADA'),
    ('ACEITA', 'FINALIZADA'),
    ('ACEITA', 'CANCELADA'),
    ('ACEITA', 'EXPIRADA'),
    ('CANCELADA_PASSAGEIRO', 'ATIVA'),
    ('CANCELADA_MOTORISTA', 'ATIVA'),
  ]) {
    test('arquiva ${caso.$1}/${caso.$2} e nao permite acao pendente', () {
      final enviada = SolicitacaoEnviada.fromJson(dados(caso.$1, caso.$2));
      final recebida = SolicitacaoRecebida.fromJson(dados(caso.$1, caso.$2));
      expect(enviada.arquivada, isTrue);
      expect(recebida.arquivada, isTrue);
      expect(enviada.podePagarPix, isFalse);
      expect(enviada.aceiteAguardandoAcao, isFalse);
      expect(enviada.podeCancelar, isFalse);
      expect(recebida.podeCancelar, isFalse);
    });
  }

  for (final status in ['PENDENTE', 'ACEITA']) {
    test('mantem solicitacao $status em carona ativa', () {
      expect(
        SolicitacaoEnviada.fromJson(dados(status, 'ATIVA')).arquivada,
        isFalse,
      );
      expect(
        SolicitacaoRecebida.fromJson(dados(status, 'ATIVA')).arquivada,
        isFalse,
      );
    });
  }

  test('contador ignora expiradas e pedidos de caronas encerradas', () {
    SolicitacaoService.sincronizarTotalSolicitacoesPendentes(
      [
        SolicitacaoRecebida.fromJson(dados('EXPIRADA', 'ATIVA')),
        SolicitacaoRecebida.fromJson(dados('PENDENTE', 'CANCELADA')),
        SolicitacaoRecebida.fromJson(dados('PENDENTE', 'ATIVA')),
      ],
      enviadas: [
        SolicitacaoEnviada.fromJson(dados('EXPIRADA', 'ATIVA')),
        SolicitacaoEnviada.fromJson(dados('ACEITA', 'FINALIZADA')),
        SolicitacaoEnviada.fromJson(dados('ACEITA', 'ATIVA')),
      ],
    );
    expect(SolicitacaoService.totalSolicitacoesPendentes.value, 2);
    SolicitacaoService.pararContadorSolicitacoesPendentes();
  });
}
