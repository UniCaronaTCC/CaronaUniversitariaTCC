import 'package:latlong2/latlong.dart';

class LocalizacaoSelecionada {
  final LatLng ponto;
  final String endereco;
  final String? cidade;
  final String? estado;
  final String? pais;
  final String? rua;
  final String? numero;
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
    this.rua,
    this.numero,
    this.pontoEspecifico = true,
  });

  bool get coordenadasValidas =>
      ponto.latitude.isFinite &&
      ponto.longitude.isFinite &&
      ponto.latitude >= -90 &&
      ponto.latitude <= 90 &&
      ponto.longitude >= -180 &&
      ponto.longitude <= 180;

  Map<String, dynamic> toJson() => {
    'latitude': ponto.latitude,
    'longitude': ponto.longitude,
    'endereco': endereco,
    'nome': nome,
    'cidade': cidade,
    'estado': estado,
    'pais': pais,
    'rua': rua,
    'numero': numero,
    'pontoEspecifico': pontoEspecifico,
  };

  factory LocalizacaoSelecionada.fromJson(Map<String, dynamic> json) {
    final latitude = json['latitude'];
    final longitude = json['longitude'];
    final endereco = json['endereco'];
    if (latitude is! num ||
        longitude is! num ||
        endereco is! String ||
        endereco.trim().isEmpty ||
        json['pontoEspecifico'] is! bool) {
      throw const FormatException('Destino salvo invalido');
    }
    if (!latitude.isFinite ||
        !longitude.isFinite ||
        latitude < -90 ||
        latitude > 90 ||
        longitude < -180 ||
        longitude > 180) {
      throw const FormatException('Coordenadas do destino invalidas');
    }
    String? textoOpcional(String campo) {
      final valor = json[campo];
      if (valor != null && valor is! String) {
        throw const FormatException('Destino salvo invalido');
      }
      return valor as String?;
    }

    final local = LocalizacaoSelecionada(
      ponto: LatLng(latitude.toDouble(), longitude.toDouble()),
      endereco: endereco,
      nome: textoOpcional('nome'),
      cidade: textoOpcional('cidade'),
      estado: textoOpcional('estado'),
      pais: textoOpcional('pais'),
      rua: textoOpcional('rua'),
      numero: textoOpcional('numero'),
      pontoEspecifico: json['pontoEspecifico'] as bool,
    );
    if (!local.coordenadasValidas) {
      throw const FormatException('Coordenadas do destino invalidas');
    }
    return local;
  }

  // Une o nome conhecido ao endereço completo.
  String get descricaoCompleta {
    final nomeLimpo = nome?.trim();

    if (nomeLimpo == null || nomeLimpo.isEmpty) {
      return endereco;
    }

    return '$nomeLimpo - $endereco';
  }
}
