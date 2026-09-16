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
  final bool recorrente;
  final bool avaliada;
  final bool podeAvaliar;
  final bool pagamentoConfirmado;
  final DateTime? pagamentoLimiteEm;

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
    this.recorrente = false,
    this.avaliada = false,
    this.podeAvaliar = false,
    this.pagamentoConfirmado = false,
    this.pagamentoLimiteEm,
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
      recorrente: carona['recorrente'] == true,
      avaliada: json['avaliada'] == true,
      podeAvaliar: json['podeAvaliar'] == true,
      pagamentoConfirmado: json['pagamentoConfirmado'] == true,
      pagamentoLimiteEm: DataHoraUtils.interpretarInstanteEmBrasilia(
        json['pagamentoLimiteEm'],
      ),
    );
  }

  String get dataFormatada => FormatadorData.relativa(dataInicio);

  String get horarioFormatado => DataHoraUtils.formatarHorarioTexto(horario);

  String get valorFormatado => formatarDoubleComoMoedaReal(valor);

  bool get caronaFinalizada => statusCarona == 'FINALIZADA';

  bool get cancelada => status.startsWith('CANCELADA_');

  String get statusExibicao => pagamentoConfirmado ? 'CONFIRMADA' : status;

  bool get podePagarPix =>
      status == 'ACEITA' &&
      !pagamentoConfirmado &&
      !recorrente &&
      !caronaFinalizada &&
      !cancelada;

  bool get podeCancelar =>
      !caronaFinalizada &&
      !cancelada &&
      !pagamentoConfirmado &&
      (status == 'PENDENTE' || status == 'ACEITA');

  String? get prazoPagamentoFormatado {
    final limite = pagamentoLimiteEm;

    if (limite == null) return null;

    String doisDigitos(int valor) => valor.toString().padLeft(2, '0');

    return '${doisDigitos(limite.day)}/${doisDigitos(limite.month)} '
        'às ${doisDigitos(limite.hour)}:${doisDigitos(limite.minute)}';
  }
}
