import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uni_carona/home/verificacao_cnh.dart';
import 'package:uni_carona/services/auth_service.dart';

void main() {
  final png = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVQIHWP4z8DwHwAFgAI/ScLbtAAAAABJRU5ErkJggg==',
  );
  final perfilAprovado = {
    'statusVerificacaoCnh': 'APROVADA',
    'cnhCategoria': 'AB',
    'cnhValidade': '2099-10-07',
  };
  tearDown(() => AuthService.usuarioLogado = null);

  testWidgets('reset temporario exige confirmacao e retorna ao formulario', (
    tester,
  ) async {
    var perfil = Map<String, dynamic>.from(perfilAprovado);
    var reinicios = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: VerificacaoCnhTela(
          carregarPerfil: () async => {'sucesso': true, 'dados': perfil},
          reiniciarTeste: () async {
            reinicios++;
            perfil = {'statusVerificacaoCnh': 'NAO_ENVIADA'};
            return {'sucesso': true};
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reiniciar CNH (teste)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(reinicios, 0);
    expect(find.text('CNH conferida'), findsOneWidget);
    await tester.tap(find.text('Reiniciar CNH (teste)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reiniciar'));
    await tester.pumpAndSettle();
    expect(reinicios, 1);
    expect(find.text('CNH conferida'), findsNothing);
    expect(find.byType(Checkbox), findsOneWidget);
    expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, false);
    expect(find.text('Reiniciar CNH (teste)'), findsNothing);
  });

  testWidgets('reset bloqueado preserva a aprovacao e mostra motivo', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: VerificacaoCnhTela(
          carregarPerfil: () async => {
            'sucesso': true,
            'dados': perfilAprovado,
          },
          reiniciarTeste: () async => {
            'sucesso': false,
            'mensagem': 'Existe carona ativa',
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reiniciar CNH (teste)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reiniciar'));
    await tester.pumpAndSettle();
    expect(find.text('CNH conferida'), findsOneWidget);
    expect(find.text('Existe carona ativa'), findsOneWidget);
  });

  testWidgets('reset aparece na CNH aprovada sem consulta extra', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: VerificacaoCnhTela(
          carregarPerfil: () async => {
            'sucesso': true,
            'dados': perfilAprovado,
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Reiniciar CNH (teste)'), findsOneWidget);
  });
  testWidgets('galeria exige aceite e mostra a foto escolhida', (tester) async {
    var escolhas = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: VerificacaoCnhTela(
          recortarFoto: (bytes) async => Uint8List.fromList(bytes),
          carregarPerfil: () async => {
            'sucesso': true,
            'dados': <String, dynamic>{},
          },
          capturarFoto: () async => throw StateError('Não deve abrir a câmera'),
          escolherFoto: () async {
            escolhas++;
            return XFile.fromData(Uint8List.fromList(png), name: 'cnh.png');
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    final galeria = find
        .widgetWithText(OutlinedButton, 'Escolher da galeria')
        .first;
    await tester.scrollUntilVisible(
      galeria,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(tester.widget<OutlinedButton>(galeria).onPressed, isNull);
    await tester.scrollUntilVisible(
      find.byType(Checkbox),
      -200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      galeria,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(galeria);
    await tester.pumpAndSettle();
    expect(escolhas, 1);
    expect(find.widgetWithText(OutlinedButton, 'Refazer foto'), findsOneWidget);
  });
  final botaoEnviar = find.ancestor(
    of: find.text('Enviar para verificação'),
    matching: find.byWidgetPredicate((widget) => widget is FilledButton),
  );

  Future<void> fotografarFrente(WidgetTester tester) async {
    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.widgetWithText(OutlinedButton, 'Fotografar').first,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(OutlinedButton, 'Fotografar').first);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      botaoEnviar,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
  }

  testWidgets('exige aceite e frente, envia e mostra aprovação', (
    tester,
  ) async {
    var status = <String, dynamic>{};
    var capturas = 0;
    var envios = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: VerificacaoCnhTela(
          recortarFoto: (bytes) async => Uint8List.fromList(bytes),
          carregarPerfil: () async => {'sucesso': true, 'dados': status},
          capturarFoto: () async {
            capturas++;
            return XFile.fromData(Uint8List.fromList(png), name: 'cnh.png');
          },
          enviarFotos: (frente, aceite) async {
            envios++;
            expect(frente, png);
            expect(aceite, isTrue);
            status = perfilAprovado;
            return {
              'sucesso': true,
              'dados': {'status': 'APROVADA'},
            };
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<OutlinedButton>(
            find.widgetWithText(OutlinedButton, 'Fotografar').first,
          )
          .onPressed,
      isNull,
    );
    await fotografarFrente(tester);
    await tester.tap(botaoEnviar);
    await tester.pumpAndSettle();
    expect(capturas, 1);
    expect(envios, 1);
    expect(find.text('CNH conferida'), findsOneWidget);
    expect(find.textContaining('Categoria AB'), findsOneWidget);
    expect(find.byType(Image), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('mantém fotos após falha de rede e aceita nova tentativa', (
    tester,
  ) async {
    var envios = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: VerificacaoCnhTela(
          recortarFoto: (bytes) async => Uint8List.fromList(bytes),
          carregarPerfil: () async => {
            'sucesso': true,
            'dados': <String, dynamic>{},
          },
          capturarFoto: () async =>
              XFile.fromData(Uint8List.fromList(png), name: 'cnh.png'),
          enviarFotos: (_, _) async {
            envios++;
            return {'sucesso': false, 'mensagem': 'Falha de conexão'};
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    await fotografarFrente(tester);
    await tester.tap(botaoEnviar);
    await tester.pumpAndSettle();
    expect(find.text('Falha de conexão'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Refazer foto'), findsWidgets);
    await tester.tap(botaoEnviar);
    await tester.pumpAndSettle();
    expect(envios, 2);
  });

  testWidgets('recusa descarta fotos e exige nova captura', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: VerificacaoCnhTela(
          recortarFoto: (bytes) async => Uint8List.fromList(bytes),
          carregarPerfil: () async => {
            'sucesso': true,
            'dados': {'statusVerificacaoCnh': 'RECUSADA'},
          },
          capturarFoto: () async =>
              XFile.fromData(Uint8List.fromList(png), name: 'cnh.png'),
          enviarFotos: (_, _) async => {
            'sucesso': true,
            'dados': {'status': 'RECUSADA'},
            'mensagem': 'Não conseguimos ler a categoria da CNH.',
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    await fotografarFrente(tester);
    await tester.tap(botaoEnviar);
    await tester.pumpAndSettle();
    expect(
      find.text('Não conseguimos ler a categoria da CNH.'),
      findsOneWidget,
    );
    expect(find.widgetWithText(OutlinedButton, 'Fotografar'), findsWidgets);
    expect(tester.widget<FilledButton>(botaoEnviar).onPressed, isNull);
  });

  testWidgets('aprovação existente dispensa fotos e cabe em tela estreita', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: VerificacaoCnhTela(
          recortarFoto: (bytes) async => Uint8List.fromList(bytes),
          carregarPerfil: () async => {
            'sucesso': true,
            'dados': perfilAprovado,
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('CNH conferida'), findsOneWidget);
    expect(find.byType(Checkbox), findsNothing);
    expect(find.text('Concluir'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('captura cabe em tela estreita com texto ampliado', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(1.5)),
          child: child!,
        ),
        home: VerificacaoCnhTela(
          recortarFoto: (bytes) async => Uint8List.fromList(bytes),
          carregarPerfil: () async => {
            'sucesso': true,
            'dados': <String, dynamic>{},
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Enviar para verificação'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
