import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
// ignore: implementation_imports
import 'package:flutter_test/src/_binding_io.dart' as test_io;
import 'package:integration_test/integration_test.dart';
import 'package:uni_carona/auth/confirmar_email.dart';
import 'package:uni_carona/auth/esqueci_senha.dart';
import 'package:uni_carona/auth/login.dart';
import 'package:uni_carona/config/app_theme.dart';
import 'package:uni_carona/home/conversa_detalhe.dart';
import 'package:uni_carona/home/recortar_cnh.dart';
import 'package:uni_carona/models/mensagem.dart';
import '../test/proximas_telas_visual_test.dart' as modelos;
import '../test/mapa_encontro_sem_gps_test.dart' as encontro;
import '../test/mapa_acompanhamento_passageiro_test.dart' as passageiro;

Future<Uint8List> imagemFicticia() async {
  final recorder=ui.PictureRecorder();
  final canvas=Canvas(recorder);
  canvas.drawColor(Colors.white,BlendMode.src);
  canvas.drawRect(const Rect.fromLTWH(20,20,180,180),Paint()..color=Colors.red);
  final picture=recorder.endRecording();
  final image=await picture.toImage(1000,800);
  final bytes=(await image.toByteData(format:ui.ImageByteFormat.png))!.buffer.asUint8List();
  image.dispose(); picture.dispose();
  return bytes;
}

void main() {
  final binding=IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  test_io.setupHttpOverrides();
  setUp(()=>binding.testTextInput.register());
  tearDown(()=>binding.testTextInput.unregister());
  for (final encerrada in [false,true]) {
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
      pending.complete({'sucesso':true,'dados':<Mensagem>[]});
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      expect(exception,isNull,reason:'Carregamento deve caber antes de a resposta chegar');
    });
  }
  testWidgets('NATIVO UI: recorte em orientacao deitada real preserva os controles',(tester) async {
    await SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeLeft]);
    addTearDown(()=>SystemChrome.setPreferredOrientations([]));
    for (var i=0;i<30;i++) {
      await tester.pump(const Duration(milliseconds:100));
      if(tester.view.physicalSize.width>tester.view.physicalSize.height)break;
    }
    expect(tester.view.physicalSize.width,greaterThan(tester.view.physicalSize.height));
    final bytes=await imagemFicticia();
    Uint8List? result;
    await tester.pumpWidget(MaterialApp(theme:AppTheme.lightTheme,
      builder:(context,child)=>MediaQuery(data:MediaQuery.of(context).copyWith(textScaler:TextScaler.linear(1.8)),child:child!),
      home:Builder(builder:(context)=>Scaffold(body:TextButton(onPressed:() async {result=await recortarCnh(context,bytes);},child:const Text('Abrir recorte')))),
    ));
    await tester.tap(find.text('Abrir recorte'));
    await tester.pumpAndSettle();
    final image=find.byType(RawImage);
    expect(image,findsOneWidget);
    binding.reportData={'recorte_deitado':{'larguraLogica':tester.view.physicalSize.width/tester.view.devicePixelRatio,'alturaLogica':tester.view.physicalSize.height/tester.view.devicePixelRatio,'previewAltura':tester.getSize(image).height}};
    for (var i=0;i<4;i++) { expect(find.byKey(ValueKey('canto-$i')).hitTestable(),findsOneWidget); }
    expect(find.text('Usar recorte').hitTestable(),findsOneWidget);
    await tester.tap(find.text('Usar recorte'));
    for (var i=0;i<30 && result==null;i++) { await tester.pump(const Duration(milliseconds:100)); }
    expect(result,isNotNull);
    expect(tester.takeException(),isNull);
    await tester.pumpWidget(const SizedBox());
    await SystemChrome.setPreferredOrientations([]);
    for(var i=0;i<10;i++){await tester.pump(const Duration(milliseconds:100));}
  });
  testWidgets('NATIVO UI: voltar na recuperacao respeita area segura e nao rola',(tester) async {
    await tester.pumpWidget(MaterialApp(theme:AppTheme.lightTheme,
      builder:(context,child)=>MediaQuery(data:MediaQuery.of(context).copyWith(textScaler:TextScaler.linear(3)),child:child!),
      home:const EsqueciSenhaTela(),
    ));
    await tester.pumpAndSettle();
    final arrow=find.byKey(const ValueKey('voltar-recuperacao'));
    final before=tester.getRect(arrow);
    final safeTop=MediaQuery.of(tester.element(arrow)).padding.top;
    expect(before.top,lessThanOrEqualTo(safeTop+24));
    expect(find.ancestor(of:arrow,matching:find.byType(AppBar)),findsOneWidget);
    await tester.ensureVisible(find.byKey(const ValueKey('login-recuperacao')));
    await tester.pumpAndSettle();
    expect(tester.getRect(arrow),before);
  });
  testWidgets('NATIVO UI: confirmar email valida o codigo e retorna ao login com callback ficticio',(tester) async {
    var calls=0;
    await tester.pumpWidget(MaterialApp(theme:AppTheme.lightTheme,home:ConfirmarEmailTela(email:'qa@example.invalid',confirmarCodigo:(email,code) async {calls++; expect(code,'123456'); return {'sucesso':true};})));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('codigo-confirmacao')),'123456');
    await tester.ensureVisible(find.byKey(const ValueKey('confirmar-email')));
    await tester.tap(find.byKey(const ValueKey('confirmar-email')));
    await tester.pumpAndSettle();
    expect(calls,1);
    expect(find.byType(LoginTela),findsOneWidget);
  });
  group('Encontro sem GPS',encontro.main);
  group('Mapa passageiro no aparelho',passageiro.main);
}
