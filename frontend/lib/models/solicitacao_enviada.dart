import '../utils/conversores_json.dart';
import '../utils/data_hora_utils.dart';
import '../utils/formatador_data.dart';
import '../utils/formatador_moeda.dart';

class SolicitacaoEnviada {
  final int id;
  final String status;
  final String localEmbarque;
  final String motorista;
  final int idCarona;
  final String destino;
  final DateTime dataInicio;
  final String horario;
  final double valor;
  final String statusCarona;
  final bool avaliada;
  final bool podeAvaliar;

  const SolicitacaoEnviada({
    required this.id,
    required this.status,
    required this.localEmbarque,
    required this.motorista,
    required this.idCarona,
    required this.destino,
    required this.dataInicio,
    required this.horario,
    required this.valor,
    this.statusCarona = 'ATIVA',
    this.avaliada = false,
    this.podeAvaliar = false,
  });

  factory SolicitacaoEnviada.fromJson(Map<String, dynamic> json) {
    final motorista = json['motorista'];
    final carona = json['carona'];

    if (motorista is! Map || carona is! Map) {
      throw const FormatException('Solicitação incompleta');
    }

    return SolicitacaoEnviada(
      id: converterJsonParaInt(json['id']),
      status: json['status']?.toString() ?? 'PENDENTE',
      localEmbarque: json['localEmbarque']?.toString() ?? '',
      motorista: motorista['nome']?.toString() ?? 'Motorista',
      idCarona: converterJsonParaInt(carona['id']),
      destino: carona['destino']?.toString() ?? '',
      dataInicio: DateTime.parse(carona['dataInicio'].toString()),
      horario: carona['horario']?.toString() ?? '',
      valor: converterJsonParaDouble(carona['valor']),
      statusCarona: carona['status']?.toString() ?? 'ATIVA',
      avaliada: json['avaliada'] == true,
      podeAvaliar: json['podeAvaliar'] == true,
    );
  }

  String get dataFormatada => FormatadorData.relativa(dataInicio);

  String get horarioFormatado => DataHoraUtils.formatarHorarioTexto(horario);

  String get valorFormatado => formatarDoubleComoMoedaReal(valor);

  bool get caronaFinalizada => statusCarona == 'FINALIZADA';

  bool get cancelada => status.startsWith('CANCELADA_');

  bool get podeCancelar =>
      !caronaFinalizada &&
      !cancelada &&
      (status == 'PENDENTE' || status == 'ACEITA');
}
