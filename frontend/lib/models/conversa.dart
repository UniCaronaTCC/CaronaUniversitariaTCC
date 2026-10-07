import '../utils/conversores_json.dart';
import 'mensagem.dart';

class Conversa {
  final int id;
  final String status;
  final String statusCarona;
  final bool encerradaPeloServidor;
  final int idSolicitacao;
  final int idPassageiro;
  final String passageiro;
  final String? fotoPassageiro;
  final int idMotorista;
  final String motorista;
  final String? fotoMotorista;
  final int idCarona;
  final String destino;
  final DateTime dataInicio;
  final String horario;
  final DateTime criadoEm;
  final DateTime? encerradaEm;
  final Mensagem? ultimaMensagem;
  final int mensagensNaoLidas;

  const Conversa({
    required this.id,
    required this.status,
    this.statusCarona = 'ATIVA',
    this.encerradaPeloServidor = false,
    required this.idSolicitacao,
    required this.idPassageiro,
    required this.passageiro,
    this.fotoPassageiro,
    required this.idMotorista,
    required this.motorista,
    this.fotoMotorista,
    required this.idCarona,
    required this.destino,
    required this.dataInicio,
    required this.horario,
    required this.criadoEm,
    this.encerradaEm,
    this.ultimaMensagem,
    this.mensagensNaoLidas = 0,
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
      statusCarona: carona['status']?.toString() ?? 'ATIVA',
      encerradaPeloServidor: json['encerrada'] == true,
      idSolicitacao: converterJsonParaInt(solicitacao['id']),
      idPassageiro: converterJsonParaInt(passageiro['id']),
      passageiro: passageiro['nome']?.toString() ?? 'Passageiro',
      fotoPassageiro: _converterFoto(passageiro['fotoPerfil']),
      idMotorista: converterJsonParaInt(motorista['id']),
      motorista: motorista['nome']?.toString() ?? 'Motorista',
      fotoMotorista: _converterFoto(motorista['fotoPerfil']),
      idCarona: converterJsonParaInt(carona['id']),
      destino: carona['destino']?.toString() ?? '',
      dataInicio: DateTime.parse(carona['dataInicio'].toString()),
      horario: carona['horario']?.toString() ?? '',
      criadoEm: DateTime.parse(json['criadoEm'].toString()).toLocal(),
      encerradaEm: DateTime.tryParse(
        json['encerradaEm']?.toString() ?? '',
      )?.toLocal(),
      mensagensNaoLidas: converterJsonParaInt(json['mensagensNaoLidas']),
      ultimaMensagem: ultimaMensagem is Map
          ? Mensagem.fromJson(Map<String, dynamic>.from(ultimaMensagem))
          : null,
    );
  }

  bool get encerrada =>
      encerradaPeloServidor ||
      status != 'ACEITA' ||
      !['ATIVA', 'LOTADA', 'EM_ANDAMENTO'].contains(statusCarona);

  DateTime? get arquivarEm => encerradaEm?.add(const Duration(hours: 24));

  bool deveArquivar(DateTime agora) =>
      encerrada && arquivarEm != null && !arquivarEm!.isAfter(agora);

  String nomeOutroParticipante(int idUsuarioAtual) {
    return idUsuarioAtual == idPassageiro ? motorista : passageiro;
  }

  String? fotoOutroParticipante(int idUsuarioAtual) {
    return idUsuarioAtual == idPassageiro ? fotoMotorista : fotoPassageiro;
  }
}

String? _converterFoto(dynamic valor) {
  final foto = valor?.toString().trim();
  return foto == null || foto.isEmpty ? null : foto;
}
