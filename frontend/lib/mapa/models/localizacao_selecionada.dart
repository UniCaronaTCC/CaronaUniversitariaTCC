import 'package:latlong2/latlong.dart';
import 'consulta_endereco.dart';

enum PrecisaoLocalizacao { ponto, rua, regiao, desconhecida }

class LocalizacaoSelecionada {
  final LatLng ponto;
  final String endereco;
  final String? cidade;
  final String? estado;
  final String? pais;
  final String? rua;
  final String? numero;
  final bool pontoEspecifico;
  final PrecisaoLocalizacao? precisao;
  final String? numeroBuscado;
  final String? logradouroBuscado;

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
    this.precisao,
    this.numeroBuscado,
    this.logradouroBuscado,
  });

  bool get numeroNaoConfirmado =>
      numeroBuscado != null &&
      (numeroBuscado!.trim().toUpperCase() != numero?.trim().toUpperCase() ||
          (logradouroBuscado != null &&
              ConsultaEndereco.normalizarLogradouro(logradouroBuscado!) !=
                  ConsultaEndereco.normalizarLogradouro(rua ?? '')));

  bool get exigeAjusteNoMapa =>
      !pontoEspecifico ||
      numeroNaoConfirmado ||
      (precisao != null && precisao != PrecisaoLocalizacao.ponto);

  bool get localConfirmavel =>
      coordenadasValidas &&
      endereco.trim().isNotEmpty &&
      (precisao == PrecisaoLocalizacao.rua ||
          precisao == PrecisaoLocalizacao.ponto ||
          (precisao == null && pontoEspecifico));

  String? get avisoPrecisao => avisoPrecisaoPara();

  String? avisoPrecisaoPara({bool ajusteOpcional = false}) {
    if (!exigeAjusteNoMapa) return null;
    final aviso = numeroNaoConfirmado
        ? 'Número $numeroBuscado não confirmado.'
        : 'Local aproximado.';
    if (ajusteOpcional) {
      return localConfirmavel
          ? '$aviso Ajuste no mapa opcional.'
          : '$aviso Escolha uma rua ou estabelecimento.';
    }
    return '$aviso Ajuste o ponto no mapa.';
  }

  LocalizacaoSelecionada comNumeroBuscado(
    String buscado, {
    String? logradouroBuscado,
  }) => LocalizacaoSelecionada(
    ponto: ponto,
    endereco: endereco,
    cidade: cidade,
    estado: estado,
    pais: pais,
    rua: rua,
    numero: numero,
    nome: nome,
    pontoEspecifico: pontoEspecifico,
    precisao: precisao,
    numeroBuscado: buscado,
    logradouroBuscado: logradouroBuscado,
  );

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
    if (precisao != null) 'precisao': precisao!.name,
    if (numeroBuscado != null) 'numeroBuscado': numeroBuscado,
    if (logradouroBuscado != null) 'logradouroBuscado': logradouroBuscado,
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

    final precisaoSalva = textoOpcional('precisao');
    PrecisaoLocalizacao? precisao;
    if (precisaoSalva != null) {
      for (final valor in PrecisaoLocalizacao.values) {
        if (valor.name == precisaoSalva) precisao = valor;
      }
      if (precisao == null) {
        throw const FormatException('Precisao do destino invalida');
      }
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
      precisao: precisao,
      numeroBuscado: textoOpcional('numeroBuscado'),
      logradouroBuscado: textoOpcional('logradouroBuscado'),
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
