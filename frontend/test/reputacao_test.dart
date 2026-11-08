import 'package:flutter_test/flutter_test.dart';
import 'package:uni_carona/models/carona.dart';
import 'package:uni_carona/models/reputacao.dart';
import 'package:uni_carona/models/solicitacao_enviada.dart';
import 'package:uni_carona/models/solicitacao_recebida.dart';

Map<String, dynamic> caronaComReputacao(Object? reputacao) => {
  'idCarona': 10,
  'origem': 'Encontro',
  'destino': 'Campus teste',
  'dataInicio': '2099-12-01',
  'horario': '18:00:00',
  'vagas': 2,
  'valor': 5,
  'usuario': {
    'idUsuario': 20,
    'nome': 'Motorista teste',
    'reputacao': reputacao,
  },
};

Map<String, dynamic> pedidoComReputacao(Object? reputacao) => {
  'id': 30,
  'status': 'PENDENTE',
  'localEmbarque': 'Praca teste',
  'embarqueLatitude': -21,
  'embarqueLongitude': -50,
  'motorista': {'id': 20, 'nome': 'Motorista teste', 'reputacao': reputacao},
  'passageiro': {'id': 40, 'nome': 'Passageiro teste', 'reputacao': reputacao},
  'carona': {
    'id': 10,
    'destino': 'Campus teste',
    'dataInicio': '2099-12-01',
    'horario': '18:00:00',
    'valor': 5,
  },
};

void main() {
  for (final dados in [
    {'media': 4.67, 'total': 3},
    {'media': '4.67', 'total': '3'},
  ]) {
    test('le resumo numerico ou textual: $dados', () {
      final reputacao = Reputacao.tentarLer(dados)!;
      expect(reputacao.media, 4.67);
      expect(reputacao.total, 3);
      expect(reputacao.mediaFormatada, '4,7');
    });
  }
  test('representa ausencia confirmada de avaliacoes', () {
    final reputacao = Reputacao.tentarLer({'media': 0, 'total': 0})!;
    expect(reputacao.total, 0);
    expect(reputacao.media, 0);
  });

  for (final dados in <Object?>[
    null,
    false,
    5,
    'erro',
    [],
    {},
    {'media': 4.5},
    {'media': 4.5, 'total': -1},
    {'media': 4.5, 'total': 1.5},
    {'media': 4.5, 'total': 0},
    {'media': 0, 'total': 2},
    {'media': -1, 'total': 2},
    {'media': 6, 'total': 2},
    {'media': 'NaN', 'total': 2},
    {'media': double.infinity, 'total': 2},
  ]) {
    test('resumo ausente/invalido nao quebra os cards: $dados', () {
      expect(Reputacao.tentarLer(dados), isNull);
      expect(
        Carona.fromJson(caronaComReputacao(dados)).reputacaoMotorista,
        isNull,
      );
      final pedido = pedidoComReputacao(dados);
      expect(SolicitacaoRecebida.fromJson(pedido).reputacaoPassageiro, isNull);
      expect(SolicitacaoEnviada.fromJson(pedido).reputacaoMotorista, isNull);
    });
  }

  test('cada modelo recebe a reputacao da pessoa correta', () {
    final pedido = pedidoComReputacao(null);
    (pedido['motorista'] as Map)['reputacao'] = {'media': 5, 'total': 1};
    (pedido['passageiro'] as Map)['reputacao'] = {'media': 3.5, 'total': 2};
    final enviada = SolicitacaoEnviada.fromJson(pedido);
    final recebida = SolicitacaoRecebida.fromJson(pedido);
    expect(enviada.reputacaoMotorista!.media, 5);
    expect(enviada.reputacaoMotorista!.total, 1);
    expect(recebida.reputacaoPassageiro!.media, 3.5);
    expect(recebida.reputacaoPassageiro!.total, 2);
    expect(recebida.status, 'PENDENTE');
    expect(enviada.podePagarPix, isFalse);
  });

  test('atualizacao dos pontos preserva a reputacao e os dados da carona', () {
    final carona = Carona.fromJson(
      caronaComReputacao({'media': 4.5, 'total': 2}),
    );
    final atualizada = carona.comPontosDoPercurso([]);
    expect(atualizada.reputacaoMotorista, same(carona.reputacaoMotorista));
    expect(atualizada.idMotorista, carona.idMotorista);
    expect(atualizada.motorista, carona.motorista);
    expect(atualizada.valor, carona.valor);
  });

  test('mantem compatibilidade com backend antigo sem os campos novos', () {
    final carona = caronaComReputacao(null);
    (carona['usuario'] as Map).remove('reputacao');
    final pedido = pedidoComReputacao(null);
    (pedido['motorista'] as Map).remove('reputacao');
    (pedido['passageiro'] as Map).remove('reputacao');
    expect(Carona.fromJson(carona).reputacaoMotorista, isNull);
    expect(SolicitacaoRecebida.fromJson(pedido).reputacaoPassageiro, isNull);
    expect(SolicitacaoEnviada.fromJson(pedido).reputacaoMotorista, isNull);
  });
}
