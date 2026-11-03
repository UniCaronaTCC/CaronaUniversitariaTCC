import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uni_carona/home/perfil.dart';
import 'package:uni_carona/home/verificacao_cnh.dart';
import 'package:uni_carona/services/auth_service.dart';
import 'package:uni_carona/widgets/conteudo_perfil_buscaeu.dart';

const perfilBase = <String, dynamic>{
  'id': 7,
  'nome': 'Pessoa',
  'tipoPerfil': 'PASSAGEIRO',
  'statusVerificacao': 'NAO_ENVIADO',
};
const cnhValida = <String, dynamic>{
  'statusVerificacaoCnh': 'APROVADA',
  'cnhCategoria': 'AB',
  'cnhValidade': '2099-10-07',
};

Future<void> abrirPerfil(
  WidgetTester tester,
  Map<String, dynamic> Function() perfil, {
  double escala = 1,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(escala)),
        child: child!,
      ),
      home: PerfilTela(
        carregarPerfil: () async => {'sucesso': true, 'dados': perfil()},
        carregarAvaliacoes: (_, _) async => {
          'sucesso': true,
          'dados': {'media': 0, 'total': 0},
        },
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    AuthService.usuarioLogado = null;
    AuthService.tokenUsuarioLogado = null;
  });
  tearDown(() {
    AuthService.usuarioLogado = null;
    AuthService.tokenUsuarioLogado = null;
  });

  for (final categoria in [
    'B',
    'AB',
    'C',
    'AC',
    'D',
    'AD',
    'E',
    'AE',
    ' ab ',
  ]) {
    testWidgets(
      'CNH valida categoria $categoria mostra passageiro e motorista',
      (tester) async {
        final perfil = {...perfilBase, ...cnhValida, 'cnhCategoria': categoria};
        AuthService.usuarioLogado = Map<String, dynamic>.from(perfil);
        await abrirPerfil(tester, () => perfil);
        expect(find.text('Passageiro e motorista'), findsOneWidget);
        expect(find.text('Passageiro'), findsNothing);
        expect(perfil['tipoPerfil'], 'PASSAGEIRO');
        expect(AuthService.usuarioLogado!['tipoPerfil'], 'PASSAGEIRO');
        expect(find.text('Cadastrar veículo'), findsOneWidget);
        expect(find.text('Perfil verificado'), findsOneWidget);
        expect(perfil['statusVerificacao'], 'NAO_ENVIADO');
        expect(AuthService.usuarioLogado!['statusVerificacao'], 'NAO_ENVIADO');
      },
    );
  }

  final cenariosSemHabilitacao = <String, Map<String, dynamic>>{
    'sem CNH': {},
    'nao enviada': {'statusVerificacaoCnh': 'NAO_ENVIADA'},
    'em analise': {...cnhValida, 'statusVerificacaoCnh': 'EM_ANALISE'},
    'recusada': {...cnhValida, 'statusVerificacaoCnh': 'RECUSADA'},
    'vencida': {...cnhValida, 'cnhValidade': '2000-01-01'},
    'sem validade': {...cnhValida, 'cnhValidade': null},
    'validade ilegivel': {...cnhValida, 'cnhValidade': 'invalida'},
    'sem categoria': {...cnhValida, 'cnhCategoria': null},
    'apenas moto': {...cnhValida, 'cnhCategoria': 'A'},
    'categoria desconhecida': {...cnhValida, 'cnhCategoria': 'X'},
    'tipo antigo motorista sem CNH': {'tipoPerfil': 'MOTORISTA'},
    'tipo antigo ambos sem CNH': {'tipoPerfil': 'AMBOS'},
  };
  for (final caso in cenariosSemHabilitacao.entries) {
    testWidgets('${caso.key} mostra somente passageiro', (tester) async {
      await abrirPerfil(tester, () => {...perfilBase, ...caso.value});
      expect(find.text('Passageiro'), findsOneWidget);
      expect(find.text('Passageiro e motorista'), findsNothing);
    });
  }

  for (final caso in <String, (String, IconData, Color)>{
    'NAO_ENVIADO': (
      'Perfil não verificado',
      Icons.verified_outlined,
      Colors.black54,
    ),
    'APROVADO': ('Perfil verificado', Icons.verified, Colors.green),
    'PENDENTE': ('Verificação pendente', Icons.schedule, Colors.orange),
    'RECUSADO': ('Verificação recusada', Icons.error_outline, Colors.red),
  }.entries) {
    testWidgets('sem CNH preserva selo geral ${caso.key}', (tester) async {
      await abrirPerfil(
        tester,
        () => {...perfilBase, 'statusVerificacao': caso.key},
      );
      final conteudo = tester.widget<ConteudoPerfilBuscaEu>(
        find.byType(ConteudoPerfilBuscaEu),
      );
      expect(conteudo.tipoPerfil, 'Passageiro');
      expect(conteudo.situacaoPerfil, caso.value.$1);
      expect(conteudo.iconeSituacao, caso.value.$2);
      expect(conteudo.corSituacao, caso.value.$3);
    });
  }

  testWidgets('verificacao geral aprovada nao substitui CNH ausente', (
    tester,
  ) async {
    await abrirPerfil(
      tester,
      () => {...perfilBase, 'statusVerificacao': 'APROVADO'},
    );
    expect(find.text('Perfil verificado'), findsOneWidget);
    expect(find.text('Passageiro'), findsOneWidget);
  });

  testWidgets('perfil reflete aprovacao ao voltar da tela da CNH', (
    tester,
  ) async {
    var perfil = {...perfilBase};
    await abrirPerfil(tester, () => perfil);
    expect(find.text('Passageiro'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Verificar CNH'), 200);
    await Scrollable.ensureVisible(
      tester.element(find.text('Verificar CNH')),
      alignment: 0.5,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Verificar CNH'));
    await tester.pumpAndSettle();
    perfil = {...perfilBase, ...cnhValida};
    await tester.scrollUntilVisible(find.text('Atualizar status'), 200);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Atualizar status'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Concluir'), -200);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Concluir'));
    await tester.pumpAndSettle();
    final conteudo = tester.widget<ConteudoPerfilBuscaEu>(
      find.byType(ConteudoPerfilBuscaEu),
    );
    expect(conteudo.tipoPerfil, 'Passageiro e motorista');
    expect(conteudo.situacaoPerfil, 'Perfil verificado');
  });

  testWidgets(
    'perfil volta a passageiro depois de reiniciar CNH e recarregar',
    (tester) async {
      var perfil = {...perfilBase, ...cnhValida};
      await abrirPerfil(tester, () => perfil);
      await tester.scrollUntilVisible(find.text('CNH conferida'), 200);
      await Scrollable.ensureVisible(
        tester.element(find.text('CNH conferida')),
        alignment: 0.5,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('CNH conferida'));
      await tester.pumpAndSettle();
      expect(find.byType(VerificacaoCnhTela), findsOneWidget);
      perfil = {...perfilBase, 'statusVerificacaoCnh': 'NAO_ENVIADA'};
      await tester.tap(find.text('Concluir'));
      await tester.pumpAndSettle();
      final conteudo = tester.widget<ConteudoPerfilBuscaEu>(
        find.byType(ConteudoPerfilBuscaEu),
      );
      expect(conteudo.tipoPerfil, 'Passageiro');
      expect(conteudo.situacaoPerfil, 'Perfil não verificado');
    },
  );

  testWidgets(
    'reabrir perfil utiliza estado atualizado sem guardar titulo antigo',
    (tester) async {
      var perfil = {...perfilBase, ...cnhValida};
      await abrirPerfil(tester, () => perfil);
      expect(find.text('Passageiro e motorista'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      perfil = {...perfilBase, 'statusVerificacaoCnh': 'RECUSADA'};
      await abrirPerfil(tester, () => perfil);
      expect(find.text('Passageiro'), findsOneWidget);
      expect(find.text('Passageiro e motorista'), findsNothing);
    },
  );

  testWidgets('titulo cabe em tela estreita e fonte ampliada', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await abrirPerfil(tester, () => {...perfilBase, ...cnhValida}, escala: 2);
    expect(find.text('Passageiro e motorista'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
