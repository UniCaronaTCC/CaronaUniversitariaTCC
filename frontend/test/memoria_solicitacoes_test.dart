import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:uni_carona/models/solicitacao_enviada.dart';
import 'package:uni_carona/models/solicitacao_recebida.dart';
import 'package:uni_carona/services/memoria_solicitacoes.dart';

Map<String, dynamic> dadosSolicitacao({String status = 'PENDENTE'}) => {
  'id': 23,
  'status': status,
  'localEmbarque': 'Terminal',
  'passageiro': {'nome': 'Passageiro'},
  'motorista': {'nome': 'Motorista'},
  'carona': {
    'id': 10,
    'destino': 'Campus',
    'dataInicio': '2026-11-06',
    'horario': '19:00:00',
    'status': 'ATIVA',
    'valor': 5,
  },
};

Map<String, dynamic> recebidasOk({bool vazia = false}) => {
  'sucesso': true,
  'dados': <SolicitacaoRecebida>[
    if (!vazia) SolicitacaoRecebida.fromJson(dadosSolicitacao()),
  ],
};

Map<String, dynamic> enviadasOk({bool vazia = false}) => {
  'sucesso': true,
  'dados': <SolicitacaoEnviada>[
    if (!vazia) SolicitacaoEnviada.fromJson(dadosSolicitacao()),
  ],
};

void main() {
  const escopo = (1, 10);
  late MemoriaSolicitacoes memoria;
  setUp(() => memoria = MemoriaSolicitacoes());

  Future<Map<String, dynamic>> carregar({bool vazia = false}) =>
      memoria.atualizar(
        escopo,
        recebidas: () async => recebidasOk(vazia: vazia),
        enviadas: () async => enviadasOk(vazia: vazia),
      );

  test('distingue ausencia de listas de um conjunto vazio valido', () async {
    expect(memoria.ler(escopo), isNull);
    expect(memoria.confirmada(escopo), isFalse);
    await carregar(vazia: true);
    expect(memoria.ler(escopo)!.recebidas, isEmpty);
    expect(memoria.ler(escopo)!.enviadas, isEmpty);
    expect(memoria.confirmada(escopo), isTrue);
  });

  test('copia ambas as listas e impede alteracao do conjunto', () async {
    final recebidas = recebidasOk();
    final enviadas = enviadasOk();
    await memoria.atualizar(
      escopo,
      recebidas: () async => recebidas,
      enviadas: () async => enviadas,
    );
    (recebidas['dados'] as List).clear();
    (enviadas['dados'] as List).clear();
    final listas = memoria.ler(escopo)!;
    expect(listas.recebidas, hasLength(1));
    expect(listas.enviadas, hasLength(1));
    expect(() => listas.recebidas.clear(), throwsUnsupportedError);
    expect(() => listas.enviadas.clear(), throwsUnsupportedError);
  });

  test(
    'nova resposta substitui as duas listas e remove itens antigos',
    () async {
      await carregar();
      await carregar(vazia: true);
      expect(memoria.ler(escopo)!.recebidas, isEmpty);
      expect(memoria.ler(escopo)!.enviadas, isEmpty);
    },
  );

  test('publica apenas quando ambas as consultas terminaram', () async {
    final recebidas = Completer<Map<String, dynamic>>();
    final enviadas = Completer<Map<String, dynamic>>();
    final pendente = memoria.atualizar(
      escopo,
      recebidas: () => recebidas.future,
      enviadas: () => enviadas.future,
    );
    recebidas.complete(recebidasOk());
    await Future<void>.delayed(Duration.zero);
    expect(memoria.ler(escopo), isNull);
    enviadas.complete(enviadasOk());
    expect((await pendente)['sucesso'], isTrue);
    expect(memoria.ler(escopo), isNotNull);
  });

  for (final falhaRecebidas in [false, true]) {
    test(
      'falha parcial preserva o conjunto anterior: $falhaRecebidas',
      () async {
        await carregar();
        final anterior = memoria.ler(escopo);
        final falha = {'sucesso': false, 'mensagem': 'Sem conexao'};
        final resultado = await memoria.atualizar(
          escopo,
          recebidas: () async =>
              falhaRecebidas ? falha : recebidasOk(vazia: true),
          enviadas: () async =>
              falhaRecebidas ? enviadasOk(vazia: true) : falha,
        );
        expect(resultado['sucesso'], isFalse);
        expect(resultado['mensagem'], 'Sem conexao');
        expect(identical(memoria.ler(escopo), anterior), isTrue);
        expect(memoria.confirmada(escopo), isFalse);
        await carregar(vazia: true);
        expect(memoria.confirmada(escopo), isTrue);
      },
    );
  }

  for (final dados in [
    null,
    {},
    [null],
    ['invalida'],
  ]) {
    for (final recebida in [false, true]) {
      test('nao aceita lista sem tipo: $dados recebida=$recebida', () async {
        await carregar();
        final anterior = memoria.ler(escopo);
        final invalida = {'sucesso': true, 'dados': dados};
        final resultado = await memoria.atualizar(
          escopo,
          recebidas: () async => recebida ? invalida : recebidasOk(),
          enviadas: () async => recebida ? enviadasOk() : invalida,
        );
        expect(resultado['sucesso'], isFalse);
        expect(identical(memoria.ler(escopo), anterior), isTrue);
        expect(memoria.confirmada(escopo), isFalse);
      });
    }
  }

  test(
    'excecao sincrona nao impede tratar o par e repetir a consulta',
    () async {
      var consultouEnviadas = false;
      final resultado = await memoria.atualizar(
        escopo,
        recebidas: () => throw StateError('teste'),
        enviadas: () async {
          consultouEnviadas = true;
          return enviadasOk();
        },
      );
      expect(resultado['sucesso'], isFalse);
      expect(consultouEnviadas, isTrue);
      await carregar();
      expect(memoria.confirmada(escopo), isTrue);
    },
  );

  test(
    'consultas simultaneas compartilham um unico par de requisicoes',
    () async {
      var total = 0;
      final recebidas = Completer<Map<String, dynamic>>();
      final enviadas = Completer<Map<String, dynamic>>();
      Future<Map<String, dynamic>> consultar() => memoria.atualizar(
        escopo,
        recebidas: () {
          total++;
          return recebidas.future;
        },
        enviadas: () {
          total++;
          return enviadas.future;
        },
      );
      final primeira = consultar();
      final segunda = consultar();
      expect(identical(primeira, segunda), isTrue);
      expect(total, 2);
      recebidas.complete(recebidasOk());
      enviadas.complete(enviadasOk());
      await Future.wait([primeira, segunda]);
    },
  );

  test(
    'nova consulta exige confirmacao mesmo havendo dados anteriores',
    () async {
      await carregar();
      final pendente = Completer<Map<String, dynamic>>();
      final consulta = memoria.atualizar(
        escopo,
        recebidas: () => pendente.future,
        enviadas: () async => enviadasOk(),
      );
      expect(memoria.ler(escopo), isNotNull);
      expect(memoria.confirmada(escopo), isFalse);
      pendente.complete(recebidasOk());
      await consulta;
      expect(memoria.confirmada(escopo), isTrue);
    },
  );

  test('invalidacoes durante leitura exigem outro par posterior', () async {
    final antiga = Completer<Map<String, dynamic>>();
    final nova = Completer<Map<String, dynamic>>();
    var totalRecebidas = 0;
    var totalEnviadas = 0;
    final consulta = memoria.atualizar(
      escopo,
      recebidas: () => ++totalRecebidas == 1 ? antiga.future : nova.future,
      enviadas: () async {
        totalEnviadas++;
        return enviadasOk();
      },
    );
    memoria.invalidar(escopo);
    memoria.invalidar(escopo);
    antiga.complete(recebidasOk());
    await Future<void>.delayed(Duration.zero);
    expect(totalRecebidas, 2);
    expect(totalEnviadas, 2);
    expect(memoria.ler(escopo), isNull);
    nova.complete(recebidasOk(vazia: true));
    await consulta;
    expect(memoria.ler(escopo)!.recebidas, isEmpty);
    expect(memoria.confirmada(escopo), isTrue);
    memoria.invalidar(escopo);
    expect(memoria.confirmada(escopo), isFalse);
    expect(memoria.ler(escopo), isNotNull);
  });

  for (final novoEscopo in [(2, 10), (1, 11)]) {
    test('resposta antiga nao contamina $novoEscopo', () async {
      final antiga = Completer<Map<String, dynamic>>();
      final consulta = memoria.atualizar(
        escopo,
        recebidas: () => antiga.future,
        enviadas: () async => enviadasOk(),
      );
      await memoria.atualizar(
        novoEscopo,
        recebidas: () async => recebidasOk(vazia: true),
        enviadas: () async => enviadasOk(vazia: true),
      );
      antiga.complete(recebidasOk());
      expect((await consulta)['codigo'], 'CONSULTA_DESCARTADA');
      expect(memoria.ler(novoEscopo)!.recebidas, isEmpty);
      expect(memoria.confirmada(novoEscopo), isTrue);
      expect(memoria.confirmada(escopo), isFalse);
    });
  }

  test(
    'limpar durante leitura nao permite restaurar dados da sessao',
    () async {
      final antiga = Completer<Map<String, dynamic>>();
      final consulta = memoria.atualizar(
        escopo,
        recebidas: () => antiga.future,
        enviadas: () async => enviadasOk(),
      );
      memoria.limpar();
      antiga.complete(recebidasOk());
      expect((await consulta)['codigo'], 'CONSULTA_DESCARTADA');
      expect(memoria.ler(escopo), isNull);
    },
  );

  testWidgets('timeout preserva dados e ignora resposta tardia', (
    tester,
  ) async {
    await carregar();
    final anterior = memoria.ler(escopo);
    final atrasada = Completer<Map<String, dynamic>>();
    final consulta = memoria.atualizar(
      escopo,
      recebidas: () => atrasada.future,
      enviadas: () async => enviadasOk(vazia: true),
    );
    await tester.pump(const Duration(seconds: 26));
    expect((await consulta)['sucesso'], isFalse);
    expect(identical(memoria.ler(escopo), anterior), isTrue);
    await carregar(vazia: true);
    atrasada.complete(recebidasOk());
    await tester.pump();
    expect(memoria.ler(escopo)!.recebidas, isEmpty);
    expect(memoria.confirmada(escopo), isTrue);
  });

  test(
    'falha assincrona nao altera conjunto confirmado anteriormente',
    () async {
      await carregar();
      final anterior = memoria.ler(escopo);
      final recebidas = Completer<Map<String, dynamic>>();
      final consulta = memoria.atualizar(
        escopo,
        recebidas: () => recebidas.future,
        enviadas: () async => enviadasOk(vazia: true),
      );
      recebidas.completeError(StateError('teste'));
      expect((await consulta)['sucesso'], isFalse);
      expect(identical(memoria.ler(escopo), anterior), isTrue);
      expect(memoria.confirmada(escopo), isFalse);
    },
  );

  test('invalidacao durante falha tambem exige nova leitura', () async {
    final antiga = Completer<Map<String, dynamic>>();
    var consultas = 0;
    final consulta = memoria.atualizar(
      escopo,
      recebidas: () => ++consultas == 1
          ? antiga.future
          : Future.value(recebidasOk(vazia: true)),
      enviadas: () async => enviadasOk(vazia: true),
    );
    memoria.invalidar(escopo);
    antiga.complete({'sucesso': false, 'mensagem': 'Falha anterior'});
    expect((await consulta)['sucesso'], isTrue);
    expect(consultas, 2);
    expect(memoria.confirmada(escopo), isTrue);
  });

  test('publica estado de consulta e falha sem perder as listas', () async {
    await carregar();
    final anterior = memoria.ler(escopo);
    final pendente = Completer<Map<String, dynamic>>();
    var avisos = 0;
    void ouvir() => avisos++;
    memoria.alteracoes.addListener(ouvir);
    final consulta = memoria.atualizar(
      escopo,
      recebidas: () => pendente.future,
      enviadas: () async => enviadasOk(),
    );
    expect(memoria.consultando, isTrue);
    await Future<void>.delayed(Duration.zero);
    expect(avisos, greaterThan(0));
    pendente.complete({'sucesso': false, 'mensagem': 'Sem internet'});
    await consulta;
    await Future<void>.delayed(Duration.zero);
    expect(memoria.consultando, isFalse);
    expect(memoria.erroAtualizacao, 'Sem internet');
    expect(identical(memoria.ler(escopo), anterior), isTrue);
    await carregar();
    expect(memoria.erroAtualizacao, isNull);
    memoria.alteracoes.removeListener(ouvir);
  });

  test(
    'notificacoes sao adiadas e agrupadas para nao reconstruir durante montagem',
    () async {
      var avisos = 0;
      void ouvir() => avisos++;
      memoria.alteracoes.addListener(ouvir);
      memoria.ler(escopo);
      memoria.invalidar(escopo);
      memoria.invalidar(escopo);
      expect(avisos, 0);
      await Future<void>.delayed(Duration.zero);
      expect(avisos, 1);
      memoria.alteracoes.removeListener(ouvir);
    },
  );
}
