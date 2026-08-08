import 'package:latlong2/latlong.dart';

class LocalizacaoSelecionada {
  final LatLng ponto;
  final String endereco;
  final String? cidade;
  final String? estado;
  final String? pais;

  // Nome digitado pelo usuário, como "UniSalesiano".
  final String? nome;

  const LocalizacaoSelecionada({
    required this.ponto,
    required this.endereco,
    this.nome,
    this.cidade,
    this.estado,
    this.pais,
  });

  // Une o nome conhecido ao endereço completo.
  String get descricaoCompleta {
    final nomeLimpo = nome?.trim();

    if (nomeLimpo == null || nomeLimpo.isEmpty) {
      return endereco;
    }

    return '$nomeLimpo - $endereco';
  }
}