import '../utils/conversores_json.dart';

const _statusCriacaoValidos = {'PREPARADA', 'CONFIRMADA', 'INCERTA', 'FALHOU'};

class PagamentoPix {
  final int id;
  final int idSolicitacao;
  final String metodo;
  final int valorCentavos;
  final String statusCriacao;
  final String? status;
  final String? pixCopiaECola;
  final String? qrCodeBase64;
  final DateTime? expiraEm;
  final bool modoTeste;

  const PagamentoPix({
    required this.id,
    required this.idSolicitacao,
    required this.metodo,
    required this.valorCentavos,
    required this.statusCriacao,
    required this.status,
    required this.pixCopiaECola,
    required this.qrCodeBase64,
    required this.expiraEm,
    required this.modoTeste,
  });

  factory PagamentoPix.fromJson(Map<String, dynamic> json) {
    final id = converterJsonParaInt(json['id']);
    final idSolicitacao = converterJsonParaInt(json['idSolicitacao']);
    final valorCentavos = converterJsonParaInt(json['valorCentavos']);
    final metodo = json['metodo']?.toString() ?? '';
    final statusCriacao = json['statusCriacao']?.toString() ?? '';
    final modoTeste = json['modoTeste'] == true;
    final expiraEmTexto = json['expiraEm']?.toString();
    final expiraEm = expiraEmTexto == null
        ? null
        : DateTime.tryParse(expiraEmTexto)?.toLocal();

    if (id <= 0 ||
        idSolicitacao <= 0 ||
        valorCentavos <= 0 ||
        metodo != 'PIX' ||
        !_statusCriacaoValidos.contains(statusCriacao) ||
        !modoTeste ||
        (expiraEmTexto != null && expiraEm == null)) {
      throw const FormatException('Pagamento Pix inválido');
    }

    return PagamentoPix(
      id: id,
      idSolicitacao: idSolicitacao,
      metodo: metodo,
      valorCentavos: valorCentavos,
      statusCriacao: statusCriacao,
      status: json['status']?.toString(),
      pixCopiaECola: json['pixCopiaECola']?.toString(),
      qrCodeBase64: json['qrCodeBase64']?.toString(),
      expiraEm: expiraEm,
      modoTeste: modoTeste,
    );
  }

  bool get pixDisponivel =>
      statusCriacao == 'CONFIRMADA' &&
      pixCopiaECola != null &&
      pixCopiaECola!.trim().isNotEmpty;
}
