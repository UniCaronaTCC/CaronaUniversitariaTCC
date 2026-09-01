import '../utils/conversores_json.dart';
import 'mensagem.dart';

class Conversa {
  final int id;
  final String status;
  final int idSolicitacao;
  final int idPassageiro;
  final String passageiro;
  final int idMotorista;
  final String motorista;
  final int idCarona;
  final String destino;
  final DateTime dataInicio;
  final String horario;
  final DateTime criadoEm;
  final Mensagem? ultimaMensagem;

  const Conversa({
    required this.id,
    required this.status,
    required this.idSolicitacao,
    required this.idPassageiro,
    required this.passageiro,
    required this.idMotorista,
    required this.motorista,
    required this.idCarona,
    required this.destino,
    required this.dataInicio,
    required this.horario,
    required this.criadoEm,
    this.ultimaMensagem,
  });

  factory Conversa.fromJson(Map<String, dynamic> json) {
    final solicitacao = json['solicitacao'];

    if (solicitacao is! Map) {
      throw const FormatException('Conversa incompleta');
    }

    final passageiro = solicitacao['passageiro'];
    final motorista = solicitacao['motorista'];
    final carona = solicitacao['carona'];

    if (passageiro is! Map || motorista is! Map || carona is! Map) {
      throw const FormatException('Participantes da conversa incompletos');
    }

    final ultimaMensagem = json['ultimaMensagem'];

    return Conversa(
      id: converterJsonParaInt(json['id']),
      status: json['status']?.toString() ?? 'ACEITA',
      idSolicitacao: converterJsonParaInt(solicitacao['id']),
      idPassageiro: converterJsonParaInt(passageiro['id']),
      passageiro: passageiro['nome']?.toString() ?? 'Passageiro',
      idMotorista: converterJsonParaInt(motorista['id']),
      motorista: motorista['nome']?.toString() ?? 'Motorista',
      idCarona: converterJsonParaInt(carona['id']),
      destino: carona['destino']?.toString() ?? '',
      dataInicio: DateTime.parse(carona['dataInicio'].toString()),
      horario: carona['horario']?.toString() ?? '',
      criadoEm: DateTime.parse(json['criadoEm'].toString()).toLocal(),
      ultimaMensagem: ultimaMensagem is Map
          ? Mensagem.fromJson(Map<String, dynamic>.from(ultimaMensagem))
          : null,
    );
  }

  bool get encerrada => status != 'ACEITA';

  String nomeOutroParticipante(int idUsuarioAtual) {
    return idUsuarioAtual == idPassageiro ? motorista : passageiro;
  }
}
