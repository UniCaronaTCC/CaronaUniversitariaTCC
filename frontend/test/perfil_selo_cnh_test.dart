import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uni_carona/services/auth_service.dart';
import 'package:uni_carona/widgets/conteudo_perfil_buscaeu.dart';

import 'perfil_tipo_cnh_test.dart' show abrirPerfil, cnhValida, perfilBase;

void main() {
  setUp(() {
    AuthService.usuarioLogado = null;
    AuthService.tokenUsuarioLogado = null;
    final anterior = WidgetController.hitTestWarningShouldBeFatal;
    WidgetController.hitTestWarningShouldBeFatal = true;
    addTearDown(() => WidgetController.hitTestWarningShouldBeFatal = anterior);
  });
  tearDown(() {
    AuthService.usuarioLogado = null;
    AuthService.tokenUsuarioLogado = null;
  });

  final estadosCnh = <String, (Map<String, dynamic>, bool)>{
    'aprovada valida': (cnhValida, true),
    'sem envio': ({}, false),
    'nao enviada com dados antigos': (
      {...cnhValida, 'statusVerificacaoCnh': 'NAO_ENVIADA'},
      false,
    ),
    'em analise com dados antigos': (
      {...cnhValida, 'statusVerificacaoCnh': 'EM_ANALISE'},
      false,
    ),
    'recusada com dados antigos': (
      {...cnhValida, 'statusVerificacaoCnh': 'RECUSADA'},
      false,
    ),
    'vencida': ({...cnhValida, 'cnhValidade': '2000-01-01'}, false),
    'validade ausente': ({...cnhValida, 'cnhValidade': null}, false),
    'categoria ausente': ({...cnhValida, 'cnhCategoria': null}, false),
    'categoria apenas moto': ({...cnhValida, 'cnhCategoria': 'A'}, false),
  };

  for (final estadoGeral in <String?>[
    null,
    'NAO_ENVIADO',
    'PENDENTE',
    'RECUSADO',
    'APROVADO',
  ]) {
    for (final estadoCnh in estadosCnh.entries) {
      testWidgets('selo geral $estadoGeral com CNH ${estadoCnh.key}', (
        tester,
      ) async {
        final perfil = Map<String, dynamic>.unmodifiable({
          ...perfilBase,
          ...estadoCnh.value.$1,
          'statusVerificacao': estadoGeral,
        });
        AuthService.usuarioLogado = Map<String, dynamic>.from(perfil);
        await abrirPerfil(tester, () => perfil);
        final conteudo = tester.widget<ConteudoPerfilBuscaEu>(
          find.byType(ConteudoPerfilBuscaEu),
        );
        final verificado = estadoGeral == 'APROVADO' || estadoCnh.value.$2;
        if (verificado) {
          expect(conteudo.situacaoPerfil, 'Perfil verificado');
          expect(conteudo.iconeSituacao, Icons.verified);
          expect(conteudo.corSituacao, Colors.green);
          expect(find.byIcon(Icons.verified), findsOneWidget);
        } else if (estadoGeral == 'PENDENTE') {
          expect(conteudo.situacaoPerfil, 'Verificação pendente');
          expect(conteudo.iconeSituacao, Icons.schedule);
          expect(conteudo.corSituacao, Colors.orange);
        } else if (estadoGeral == 'RECUSADO') {
          expect(conteudo.situacaoPerfil, 'Verificação recusada');
          expect(conteudo.iconeSituacao, Icons.error_outline);
          expect(conteudo.corSituacao, Colors.red);
        } else {
          expect(conteudo.situacaoPerfil, 'Perfil não verificado');
          expect(conteudo.iconeSituacao, Icons.verified_outlined);
          expect(conteudo.corSituacao, Colors.black54);
        }
        expect(
          conteudo.tipoPerfil,
          estadoCnh.value.$2 ? 'Passageiro e motorista' : 'Passageiro',
        );
        expect(perfil['statusVerificacao'], estadoGeral);
        expect(AuthService.usuarioLogado!['statusVerificacao'], estadoGeral);
        expect(
          AuthService.usuarioLogado!['statusVerificacaoCnh'],
          perfil['statusVerificacaoCnh'],
        );
        expect(AuthService.usuarioLogado!['tipoPerfil'], 'PASSAGEIRO');
      });
    }
  }

  for (final estadoGeral in ['NAO_ENVIADO', 'APROVADO']) {
    testWidgets(
      'reinicio da CNH preserva somente selo independente $estadoGeral',
      (tester) async {
        var perfil = {
          ...perfilBase,
          ...cnhValida,
          'statusVerificacao': estadoGeral,
        };
        await abrirPerfil(tester, () => perfil);
        expect(find.text('Perfil verificado'), findsOneWidget);
        await tester.scrollUntilVisible(find.text('CNH conferida'), 200);
        await Scrollable.ensureVisible(
          tester.element(find.text('CNH conferida')),
          alignment: 0.5,
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('CNH conferida'));
        await tester.pumpAndSettle();
        perfil = {
          ...perfilBase,
          'statusVerificacao': estadoGeral,
          'statusVerificacaoCnh': 'NAO_ENVIADA',
        };
        await tester.tap(find.text('Concluir'));
        await tester.pumpAndSettle();
        final conteudo = tester.widget<ConteudoPerfilBuscaEu>(
          find.byType(ConteudoPerfilBuscaEu),
        );
        expect(conteudo.tipoPerfil, 'Passageiro');
        expect(
          conteudo.situacaoPerfil,
          estadoGeral == 'APROVADO'
              ? 'Perfil verificado'
              : 'Perfil não verificado',
        );
        expect(
          conteudo.iconeSituacao,
          estadoGeral == 'APROVADO' ? Icons.verified : Icons.verified_outlined,
        );
      },
    );
  }

  testWidgets('reabrir com CNH vencida remove selo derivado da CNH', (
    tester,
  ) async {
    var perfil = {...perfilBase, ...cnhValida};
    await abrirPerfil(tester, () => perfil);
    expect(find.text('Perfil verificado'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    perfil = {...perfil, 'cnhValidade': '2000-01-01'};
    await abrirPerfil(tester, () => perfil);
    expect(find.text('Perfil não verificado'), findsOneWidget);
    expect(find.byIcon(Icons.verified), findsNothing);
    expect(find.text('Passageiro'), findsOneWidget);
  });

  for (final escala in [1.0, 2.0]) {
    testWidgets('selo e texto cabem em tela estreita com fonte $escala', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await abrirPerfil(
        tester,
        () => {...perfilBase, ...cnhValida},
        escala: escala,
      );
      final selo = find.text('Perfil verificado');
      final tipo = find.text('Passageiro e motorista');
      expect(selo, findsOneWidget);
      expect(tipo, findsOneWidget);
      expect(tester.getRect(selo).overlaps(tester.getRect(tipo)), isFalse);
      expect(tester.takeException(), isNull);
    });
  }
}
