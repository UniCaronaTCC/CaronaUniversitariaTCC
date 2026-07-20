import 'package:latlong2/latlong.dart';

class LocalizacaoSelecionada {
  final LatLng ponto;
  final String endereco;

  // Nome digitado pelo usuario, como "UniSalesiano".
  final String? nome;

  const LocalizacaoSelecionada({
    required this.ponto,
    required this.endereco,
    this.nome,
  });

  // Une o nome conhecido ao endereco completo.
  String get descricaoCompleta {
    final nomeLimpo = nome?.trim();

    if (nomeLimpo == null || nomeLimpo.isEmpty) {
      return endereco;
    }

    return '$nomeLimpo - $endereco';
  }
}