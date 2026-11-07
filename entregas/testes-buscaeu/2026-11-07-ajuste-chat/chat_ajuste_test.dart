import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
// ignore: implementation_imports
import 'package:flutter_test/src/_binding_io.dart' as test_io;
import 'package:integration_test/integration_test.dart';
import 'package:uni_carona/config/app_theme.dart';
import 'package:uni_carona/home/conversa_detalhe.dart';
import 'package:uni_carona/models/mensagem.dart';
import '../test/proximas_telas_visual_test.dart' as modelos;

void main() {
  final binding=IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  test_io.setupHttpOverrides();
  setUp(()=>binding.testTextInput.register());
  tearDown(()=>binding.testTextInput.unregister());
  for(final encerrada in [false,true]) {
    testWidgets('REPRO: chat carrega sem overflow em tela pequena encerrada=$encerrada',(tester) async {
      await binding.setSurfaceSize(Size(320,encerrada?560:700));
      addTearDown(()=>binding.setSurfaceSize(null));
      modelos.textosLongos=true;
      final pending=Completer<Map<String,dynamic>>();
      await tester.pumpWidget(MaterialApp(theme:AppTheme.lightTheme,
        builder:(context,child)=>MediaQuery(data:MediaQuery.of(context).copyWith(textScaler:TextScaler.linear(encerrada?1.8:1.5),viewInsets:EdgeInsets.only(bottom:encerrada?0:300)),child:child!),
        home:ConversaDetalheTela(conversa:modelos.conversa(3,'Pessoa de teste','Mensagem',encerrada:encerrada),idUsuario:1,usarRealtime:false,carregarMensagens:()=>pending.future),
      ));
      await tester.pump(const Duration(milliseconds:150));
      final exception=tester.takeException();
      await tester.ensureVisible(find.text('Buscando o histórico desta conversa.'));
      await tester.pump();
      expect(find.text('Buscando o histórico desta conversa.').hitTestable(),findsOneWidget);
      pending.complete({'sucesso':true,'dados':<Mensagem>[]});
      await tester.pumpAndSettle();
      expect(tester.takeException(),isNull);
      expect(find.byType(TextField),encerrada?findsNothing:findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      expect(exception,isNull,reason:'Carregamento deve caber antes de a resposta chegar');
    });
  }
}
