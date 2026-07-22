import '../utils/formatador_data.dart';

class SolicitacaoEnviada {
  final int id;
  final String status;
  final String localEmbarque;
  final String motorista;
  final int idCarona;
  final String destino;
  final DateTime dataInicio;
  final String horario;

  const SolicitacaoEnviada({
    required this.id,
    required this.status,
    required this.localEmbarque,
    required this.motorista,
    required this.idCarona,
    required this.destino,
    required this.dataInicio,
    required this.horario,
  });

  factory SolicitacaoEnviada.fromJson(Map<String, dynamic> json) {
    final motorista = json['motorista'];
    final carona = json['carona'];

    if (motorista is! Map || carona is! Map) {
      throw const FormatException('Solicitação incompleta');
    }

    return SolicitacaoEnviada(
      id: _converterInt(json['id']),
      status: json['status']?.toString() ?? 'PENDENTE',
      localEmbarque: json['localEmbarque']?.toString() ?? '',
      motorista: motorista['nome']?.toString() ?? 'Motorista',
      idCarona: _converterInt(carona['id']),
      destino: carona['destino']?.toString() ?? '',
      dataInicio: DateTime.parse(carona['dataInicio'].toString()),
      horario: carona['horario']?.toString() ?? '',
    );
  }

  String get dataFormatada => FormatadorData.relativa(dataInicio);

  String get horarioFormatado {
    final partes = horario.split(':');

    return partes.length >= 2 ? '${partes[0]}:${partes[1]}' : horario;
  }

  static int _converterInt(dynamic valor) {
    return valor is int ? valor : int.tryParse(valor?.toString() ?? '') ?? 0;
  }
}
