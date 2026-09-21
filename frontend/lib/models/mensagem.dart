import '../utils/conversores_json.dart';

enum EstadoEnvioMensagem { enviada, enviando, erro }

class Mensagem {
  final int id;
  final String conteudo;
  final DateTime criadoEm;
  final int idRemetente;
  final EstadoEnvioMensagem estadoEnvio;

  const Mensagem({
    required this.id,
    required this.conteudo,
    required this.criadoEm,
    required this.idRemetente,
    this.estadoEnvio = EstadoEnvioMensagem.enviada,
  });

  Mensagem copyWith({EstadoEnvioMensagem? estadoEnvio}) {
    return Mensagem(
      id: id,
      conteudo: conteudo,
      criadoEm: criadoEm,
      idRemetente: idRemetente,
      estadoEnvio: estadoEnvio ?? this.estadoEnvio,
    );
  }

  factory Mensagem.fromJson(Map<String, dynamic> json) {
    final remetente = json['remetente'];

    if (remetente is! Map) {
      throw const FormatException('Mensagem incompleta');
    }

    return Mensagem(
      id: converterJsonParaInt(json['id']),
      conteudo: json['conteudo']?.toString() ?? '',
      criadoEm: DateTime.parse(json['criadoEm'].toString()).toLocal(),
      idRemetente: converterJsonParaInt(remetente['id']),
    );
  }
}
