import '../utils/conversores_json.dart';
import '../utils/data_hora_utils.dart';
import '../utils/formatador_data.dart';

class SolicitacaoRecebida {
  final int id;
  final String status;
  final String localEmbarque;
  final double embarqueLatitude;
  final double embarqueLongitude;
  final String passageiro;
  final int idCarona;
  final String destino;
  final DateTime dataInicio;
  final String horario;

  const SolicitacaoRecebida({
    required this.id,
    required this.status,
    required this.localEmbarque,
    required this.embarqueLatitude,
    required this.embarqueLongitude,
    required this.passageiro,
    required this.idCarona,
    required this.destino,
    required this.dataInicio,
    required this.horario,
  });

  factory SolicitacaoRecebida.fromJson(Map<String, dynamic> json) {
    final passageiro = json['passageiro'];
    final carona = json['carona'];

    if (passageiro is! Map || carona is! Map) {
      throw const FormatException('Solicitação incompleta');
    }

    return SolicitacaoRecebida(
      id: converterJsonParaInt(json['id']),
      status: json['status']?.toString() ?? 'PENDENTE',
      localEmbarque: json['localEmbarque']?.toString() ?? '',
      embarqueLatitude: converterJsonParaDouble(json['embarqueLatitude']),
      embarqueLongitude: converterJsonParaDouble(json['embarqueLongitude']),
      passageiro: passageiro['nome']?.toString() ?? 'Passageiro',
      idCarona: converterJsonParaInt(carona['id']),
      destino: carona['destino']?.toString() ?? '',
      dataInicio: DateTime.parse(carona['dataInicio'].toString()),
      horario: carona['horario']?.toString() ?? '',
    );
  }

  String get dataFormatada => FormatadorData.relativa(dataInicio);

  String get horarioFormatado => DataHoraUtils.formatarHorarioTexto(horario);
}
