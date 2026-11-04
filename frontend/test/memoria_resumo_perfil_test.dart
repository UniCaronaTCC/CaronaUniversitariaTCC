import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:uni_carona/services/memoria_resumo_perfil.dart';

Map<String, dynamic> resumoOk({double media = 4.5, int total = 2}) => {
  'sucesso': true,
  'dados': {'media': media, 'total': total},
};

void main() {
  const escopo = (1, 10);
  late MemoriaResumoPerfil memoria;
  setUp(() => memoria = MemoriaResumoPerfil());

  test(
    'ausencia nao equivale a zero avaliacoes confirmado pelo servidor',
    () async {
      expect(memoria.ler(escopo), isNull);
      final resultado = await memoria.atualizar(
        escopo,
        () async => resumoOk(media: 0, total: 0),
      );
      expect(resultado['sucesso'], isTrue);
      expect(memoria.ler(escopo)!.media, 0);
      expect(memoria.ler(escopo)!.total, 0);
    },
  );

  test(
    'guarda so escalares, sem reter o mapa nem comentarios do servidor',
    () async {
      final dados = {
        'media': 4.5,
        'total': 2,
        'avaliacoes': ['comentario sintetico'],
      };
      await memoria.atualizar(
        escopo,
        () async => {'sucesso': true, 'dados': dados},
      );
      dados['media'] = 1;
      dados['total'] = 99;
      dados.clear();
      final resumo = memoria.ler(escopo)!;
      expect(resumo.media, 4.5);
      expect(resumo.total, 2);
    },
  );

  test(
    'substitui o resumo anterior inclusive quando o novo tem zero avaliacoes',
    () async {
      await memoria.atualizar(escopo, () async => resumoOk());
      await memoria.atualizar(escopo, () async => resumoOk(media: 0, total: 0));
      expect(memoria.ler(escopo)!.media, 0);
      expect(memoria.ler(escopo)!.total, 0);
    },
  );

  for (final dados in <Object?>[
    null,
    [],
    {},
    {'media': 4},
    {'total': 2},
    {'media': null, 'total': 2},
    {'media': true, 'total': 2},
    {'media': -1, 'total': 2},
    {'media': 5.1, 'total': 2},
    {'media': 'NaN', 'total': 2},
    {'media': 'Infinity', 'total': 2},
    {'media': '4,5', 'total': 2},
    {'media': 4.5, 'total': -1},
    {'media': 4.5, 'total': 1.5},
    {'media': 4.5, 'total': true},
    {'media': 4.5, 'total': null},
  ]) {
    test('resumo invalido nao apaga nota anterior: $dados', () async {
      await memoria.atualizar(escopo, () async => resumoOk());
      final anterior = memoria.ler(escopo);
      final resultado = await memoria.atualizar(
        escopo,
        () async => {'sucesso': true, 'dados': dados},
      );
      expect(resultado['sucesso'], isFalse);
      expect(identical(memoria.ler(escopo), anterior), isTrue);
      expect(memoria.erroAtualizacao, isNotNull);
      expect(memoria.consultando, isFalse);
    });
  }

  test('aceita numeros e representacoes numericas do contrato', () {
    for (final media in [0, 5, 4.5, '4.50']) {
      final resumo = ResumoAvaliacoesPerfil.fromJson({
        'media': media,
        'total': '12',
      });
      expect(resumo.media, double.parse(media.toString()));
      expect(resumo.total, 12);
    }
  });

  test(
    'falha preserva resumo e mensagem, e nova tentativa limpa o erro',
    () async {
      await memoria.atualizar(escopo, () async => resumoOk());
      final resultado = await memoria.atualizar(
        escopo,
        () async => {'sucesso': false, 'mensagem': 'Sem internet'},
      );
      expect(resultado['mensagem'], 'Sem internet');
      expect(memoria.erroAtualizacao, 'Sem internet');
      expect(memoria.ler(escopo)!.media, 4.5);
      await memoria.atualizar(escopo, () async => resumoOk(media: 5, total: 3));
      expect(memoria.erroAtualizacao, isNull);
      expect(memoria.ler(escopo)!.media, 5);
    },
  );

  test('falha inicial nao inventa nota zero nem quantidade zero', () async {
    await memoria.atualizar(escopo, () async => {'sucesso': false});
    expect(memoria.ler(escopo), isNull);
    expect(memoria.erroAtualizacao, isNotNull);
  });

  test('excecao sincrona libera a consulta e permite nova tentativa', () async {
    final resultado = await memoria.atualizar(
      escopo,
      () => throw StateError('teste'),
    );
    expect(resultado['sucesso'], isFalse);
    expect(memoria.consultando, isFalse);
    await memoria.atualizar(escopo, () async => resumoOk());
    expect(memoria.ler(escopo), isNotNull);
  });

  test('consultas simultaneas compartilham o mesmo pedido', () async {
    var consultas = 0;
    final pendente = Completer<Map<String, dynamic>>();
    Future<Map<String, dynamic>> consultar() {
      consultas++;
      return pendente.future;
    }

    final primeira = memoria.atualizar(escopo, consultar);
    final segunda = memoria.atualizar(escopo, consultar);
    expect(identical(primeira, segunda), isTrue);
    expect(consultas, 1);
    expect(memoria.consultando, isTrue);
    pendente.complete(resumoOk());
    await Future.wait([primeira, segunda]);
    expect(memoria.consultando, isFalse);
  });

  test('resumo anterior continua disponivel durante revalidacao', () async {
    await memoria.atualizar(escopo, () async => resumoOk());
    final pendente = Completer<Map<String, dynamic>>();
    final consulta = memoria.atualizar(escopo, () => pendente.future);
    expect(memoria.ler(escopo)!.media, 4.5);
    expect(memoria.consultando, isTrue);
    pendente.complete(resumoOk(media: 5));
    await consulta;
    expect(memoria.ler(escopo)!.media, 5);
  });

  for (final novoEscopo in [(2, 10), (1, 11)]) {
    test('resposta de $escopo nao contamina $novoEscopo', () async {
      final antiga = Completer<Map<String, dynamic>>();
      final consultaAntiga = memoria.atualizar(escopo, () => antiga.future);
      await memoria.atualizar(
        novoEscopo,
        () async => resumoOk(media: 1, total: 1),
      );
      antiga.complete(resumoOk());
      expect((await consultaAntiga)['codigo'], 'CONSULTA_DESCARTADA');
      expect(memoria.ler(novoEscopo)!.media, 1);
      expect(memoria.consultando, isFalse);
    });
  }

  test(
    'limpar impede restauracao por resultado de uma consulta antiga',
    () async {
      final antiga = Completer<Map<String, dynamic>>();
      final consulta = memoria.atualizar(escopo, () => antiga.future);
      memoria.limpar();
      antiga.complete(resumoOk());
      expect((await consulta)['codigo'], 'CONSULTA_DESCARTADA');
      expect(memoria.ler(escopo), isNull);
      expect(memoria.erroAtualizacao, isNull);
    },
  );

  test(
    'invalidacoes durante GET exigem uma consulta posterior e sao agrupadas',
    () async {
      final antiga = Completer<Map<String, dynamic>>();
      final nova = Completer<Map<String, dynamic>>();
      var consultas = 0;
      final consulta = memoria.atualizar(
        escopo,
        () => ++consultas == 1 ? antiga.future : nova.future,
      );
      memoria.invalidar(escopo);
      memoria.invalidar(escopo);
      antiga.complete(resumoOk());
      await Future<void>.delayed(Duration.zero);
      expect(consultas, 2);
      expect(memoria.ler(escopo), isNull);
      nova.complete(resumoOk(media: 5));
      await consulta;
      expect(memoria.ler(escopo)!.media, 5);
    },
  );

  testWidgets(
    'timeout preserva resumo, libera retry e ignora resposta tardia',
    (tester) async {
      await memoria.atualizar(escopo, () async => resumoOk());
      final atrasada = Completer<Map<String, dynamic>>();
      final consulta = memoria.atualizar(escopo, () => atrasada.future);
      await tester.pump(const Duration(seconds: 26));
      expect((await consulta)['sucesso'], isFalse);
      expect(memoria.ler(escopo)!.media, 4.5);
      expect(memoria.consultando, isFalse);
      await memoria.atualizar(escopo, () async => resumoOk(media: 1));
      atrasada.complete(resumoOk(media: 5));
      await tester.pump();
      expect(memoria.ler(escopo)!.media, 1);
    },
  );

  test(
    'terminar consulta antiga nao libera a consulta em andamento da nova conta',
    () async {
      final antiga = Completer<Map<String, dynamic>>();
      final nova = Completer<Map<String, dynamic>>();
      final primeira = memoria.atualizar(escopo, () => antiga.future);
      final segunda = memoria.atualizar((2, 10), () => nova.future);
      antiga.complete(resumoOk());
      expect((await primeira)['codigo'], 'CONSULTA_DESCARTADA');
      expect(memoria.consultando, isTrue);
      final compartilhada = memoria.atualizar((
        2,
        10,
      ), () async => resumoOk(media: 1));
      expect(identical(compartilhada, segunda), isTrue);
      nova.complete(resumoOk(media: 5));
      await segunda;
      expect(memoria.ler((2, 10))!.media, 5);
    },
  );
}
