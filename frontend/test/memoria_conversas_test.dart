import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:uni_carona/models/conversa.dart';
import 'package:uni_carona/services/auth_service.dart';
import 'package:uni_carona/services/memoria_conversas.dart';

import 'conversa_estado_test.dart' show conversaJson;

void main() {
  const escopo = (1, 10);
  late MemoriaConversas memoria;
  List<Conversa> lista(String status) => [
    Conversa.fromJson(conversaJson(status)),
  ];
  Map<String, dynamic> ok(List<Conversa> dados) => {
    'sucesso': true,
    'dados': dados,
  };

  setUp(() => memoria = MemoriaConversas());

  test('distingue ausencia de resposta de uma lista vazia valida', () async {
    expect(memoria.ler(escopo), isNull);
    await memoria.atualizar(escopo, () async => ok([]));
    expect(memoria.ler(escopo), isEmpty);
    expect(memoria.ler(escopo), isNotNull);
  });

  test('copia a lista e impede modificacao acidental da memoria', () async {
    final original = lista('ATIVA');
    await memoria.atualizar(escopo, () async => ok(original));
    original.clear();
    expect(memoria.ler(escopo), hasLength(1));
    expect(() => memoria.ler(escopo)!.clear(), throwsUnsupportedError);
  });

  test('consulta completa substitui e remove itens antigos', () async {
    await memoria.atualizar(escopo, () async => ok(lista('ATIVA')));
    await memoria.atualizar(escopo, () async => ok([]));
    expect(memoria.ler(escopo), isEmpty);
  });

  for (final dados in [
    null,
    {},
    [null],
    ['invalida'],
  ]) {
    test('resposta invalida $dados nao apaga lista anterior', () async {
      await memoria.atualizar(escopo, () async => ok(lista('ATIVA')));
      final resultado = await memoria.atualizar(
        escopo,
        () async => {'sucesso': true, 'dados': dados},
      );
      expect(resultado['sucesso'], isFalse);
      expect(memoria.ler(escopo), hasLength(1));
    });
  }

  test('falha e excecao preservam dados e permitem nova tentativa', () async {
    await memoria.atualizar(escopo, () async => ok(lista('ATIVA')));
    expect(
      (await memoria.atualizar(
        escopo,
        () async => throw StateError('teste'),
      ))['sucesso'],
      isFalse,
    );
    expect(memoria.ler(escopo), hasLength(1));
    await memoria.atualizar(escopo, () async => ok([]));
    expect(memoria.ler(escopo), isEmpty);
  });

  test('reaberturas compartilham uma consulta em andamento', () async {
    var consultas = 0;
    final resposta = Completer<Map<String, dynamic>>();
    Future<Map<String, dynamic>> carregar() {
      consultas++;
      return resposta.future;
    }

    final primeira = memoria.atualizar(escopo, carregar);
    final segunda = memoria.atualizar(escopo, carregar);
    expect(identical(primeira, segunda), isTrue);
    expect(consultas, 1);
    resposta.complete(ok([]));
    await Future.wait([primeira, segunda]);
  });

  test(
    'eventos durante consulta descartam resposta velha e agrupam nova consulta',
    () async {
      final antiga = Completer<Map<String, dynamic>>();
      final nova = Completer<Map<String, dynamic>>();
      var consultas = 0;
      final pendente = memoria.atualizar(
        escopo,
        () => ++consultas == 1 ? antiga.future : nova.future,
      );
      memoria.invalidar(escopo);
      memoria.invalidar(escopo);
      antiga.complete(ok(lista('ATIVA')));
      await Future<void>.delayed(Duration.zero);
      expect(consultas, 2);
      expect(memoria.ler(escopo), isNull);
      nova.complete(ok(lista('FINALIZADA')));
      await pendente;
      expect(memoria.ler(escopo)!.single.statusCarona, 'FINALIZADA');
    },
  );

  for (final novoEscopo in [(2, 10), (1, 11)]) {
    test('resposta de $escopo nao contamina $novoEscopo', () async {
      final antiga = Completer<Map<String, dynamic>>();
      final pendente = memoria.atualizar(escopo, () => antiga.future);
      expect(memoria.ler(novoEscopo), isNull);
      await memoria.atualizar(novoEscopo, () async => ok([]));
      antiga.complete(ok(lista('ATIVA')));
      expect((await pendente)['codigo'], 'CONSULTA_DESCARTADA');
      expect(memoria.ler(novoEscopo), isEmpty);
    });
  }

  test(
    'limpeza impede que uma consulta antiga recupere dados privados',
    () async {
      final antiga = Completer<Map<String, dynamic>>();
      final pendente = memoria.atualizar(escopo, () => antiga.future);
      memoria.limpar();
      antiga.complete(ok(lista('ATIVA')));
      expect((await pendente)['codigo'], 'CONSULTA_DESCARTADA');
      expect(memoria.ler(escopo), isNull);
    },
  );

  test(
    'invalidar sessao limpa memoria compartilhada; trocar token nao',
    () async {
      final chave = (1, AuthService.versaoSessao);
      await MemoriaConversas.compartilhada.atualizar(
        chave,
        () async => ok(lista('ATIVA')),
      );
      AuthService.tokenUsuarioLogado = 'token-renovado-sintetico';
      expect(AuthService.versaoSessao, chave.$2);
      expect(MemoriaConversas.compartilhada.ler(chave), hasLength(1));
      AuthService.tokenUsuarioLogado = null;
      expect(AuthService.versaoSessao, greaterThan(chave.$2));
      expect(MemoriaConversas.compartilhada.ler(chave), isNull);
    },
  );

  testWidgets('timeout libera consulta sem aceitar uma resposta tardia', (
    tester,
  ) async {
    final resposta = Completer<Map<String, dynamic>>();
    final pendente = memoria.atualizar(escopo, () => resposta.future);
    await tester.pump(const Duration(seconds: 26));
    expect((await pendente)['sucesso'], isFalse);
    await memoria.atualizar(escopo, () async => ok([]));
    resposta.complete(ok(lista('ATIVA')));
    await tester.pump();
    expect(memoria.ler(escopo), isEmpty);
  });
}
