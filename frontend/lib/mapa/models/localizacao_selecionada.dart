import 'package:latlong2/latlong.dart';

class LocalizacaoSelecionada {
  final LatLng ponto;
  final String endereco;
  final String? cidade;
  final String? estado;
  final String? pais;
  final bool pontoEspecifico;

  // Nome digitado pelo usuário, como "UniSalesiano".
  final String? nome;

  const LocalizacaoSelecionada({
    required this.ponto,
    required this.endereco,
    this.nome,
    this.cidade,
    this.estado,
    this.pais,
    this.pontoEspecifico = true,
  });

  bool get coordenadasValidas =>
      ponto.latitude.isFinite &&
      ponto.longitude.isFinite &&
      ponto.latitude >= -90 &&
      ponto.latitude <= 90 &&
      ponto.longitude >= -180 &&
      ponto.longitude <= 180;

  // Une o nome conhecido ao endereço completo.
  String get descricaoCompleta {
    final nomeLimpo = nome?.trim();

    if (nomeLimpo == null || nomeLimpo.isEmpty) {
      return endereco;
    }

    return '$nomeLimpo - $endereco';
  }
}
