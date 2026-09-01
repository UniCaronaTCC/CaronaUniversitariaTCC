import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uni_carona/home/conversa_detalhe.dart';
import 'package:uni_carona/models/conversa.dart';
import 'package:uni_carona/models/mensagem.dart';

void main() {
  final conversa = Conversa(
    id: 1,
    status: 'ACEITA',
    idSolicitacao: 10,
    idPassageiro: 1,
    passageiro: 'João',
    idMotorista: 2,
    motorista: 'Maria',
    idCarona: 20,
    destino: 'UniSalesiano',
    dataInicio: DateTime(2026, 9, 2),
    horario: '19:00:00',
    criadoEm: DateTime(2026, 9, 1),
  );

  testWidgets('mostra histórico e envia nova mensagem', (tester) async {
    var textoEnviado = '';

    await tester.pumpWidget(
      MaterialApp(
        home: ConversaDetalheTela(
          conversa: conversa,
          idUsuario: 1,
          usarRealtime: false,
          carregarMensagens: () async => {
            'sucesso': true,
            'dados': [
              Mensagem(
                id: 1,
                conteudo: 'Boa tarde!',
                criadoEm: DateTime(2026, 9, 1, 18),
                idRemetente: 2,
              ),
            ],
          },
          enviarMensagem: (texto) async {
            textoEnviado = texto;
            return {
              'sucesso': true,
              'dados': Mensagem(
                id: 2,
                conteudo: texto,
                criadoEm: DateTime(2026, 9, 1, 18, 5),
                idRemetente: 1,
              ),
            };
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Maria'), findsOneWidget);
    expect(find.text('Boa tarde!'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Estou chegando');
    await tester.tap(find.byTooltip('Enviar mensagem'));
    await tester.pumpAndSettle();

    expect(textoEnviado, 'Estou chegando');
    expect(find.text('Estou chegando'), findsOneWidget);
  });

  testWidgets('conversa encerrada fica somente para leitura', (tester) async {
    final conversaEncerrada = Conversa(
      id: conversa.id,
      status: 'CANCELADA_PASSAGEIRO',
      idSolicitacao: conversa.idSolicitacao,
      idPassageiro: conversa.idPassageiro,
      passageiro: conversa.passageiro,
      idMotorista: conversa.idMotorista,
      motorista: conversa.motorista,
      idCarona: conversa.idCarona,
      destino: conversa.destino,
      dataInicio: conversa.dataInicio,
      horario: conversa.horario,
      criadoEm: conversa.criadoEm,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: ConversaDetalheTela(
          conversa: conversaEncerrada,
          idUsuario: 1,
          usarRealtime: false,
          carregarMensagens: () async => {
            'sucesso': true,
            'dados': <Mensagem>[],
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Esta conversa foi encerrada'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    expect(find.byTooltip('Enviar mensagem'), findsNothing);
  });
}
