import 'package:diacritic/diacritic.dart';
import 'package:latlong2/latlong.dart';

import '../mapa/models/localizacao_selecionada.dart';

String normalizarDestino(String texto) => removeDiacritics(
  texto,
).toLowerCase().trim().replaceAll(RegExp(r'\s+'), ' ');

class CidadeCampus {
  final String cidade;
  final String uf;

  const CidadeCampus(this.cidade, this.uf);

  static const estados = {
    'AC': 'Acre',
    'AL': 'Alagoas',
    'AP': 'Amapá',
    'AM': 'Amazonas',
    'BA': 'Bahia',
    'CE': 'Ceará',
    'DF': 'Distrito Federal',
    'ES': 'Espírito Santo',
    'GO': 'Goiás',
    'MA': 'Maranhão',
    'MT': 'Mato Grosso',
    'MS': 'Mato Grosso do Sul',
    'MG': 'Minas Gerais',
    'PA': 'Pará',
    'PB': 'Paraíba',
    'PR': 'Paraná',
    'PE': 'Pernambuco',
    'PI': 'Piauí',
    'RJ': 'Rio de Janeiro',
    'RN': 'Rio Grande do Norte',
    'RS': 'Rio Grande do Sul',
    'RO': 'Rondônia',
    'RR': 'Roraima',
    'SC': 'Santa Catarina',
    'SP': 'São Paulo',
    'SE': 'Sergipe',
    'TO': 'Tocantins',
  };

  static String? normalizarUf(String? estado) {
    final texto = normalizarDestino(estado ?? '');
    for (final entrada in estados.entries) {
      if (texto == entrada.key.toLowerCase() ||
          texto == normalizarDestino(entrada.value)) {
        return entrada.key;
      }
    }
    return null;
  }

  static CidadeCampus? deLocalizacao(LocalizacaoSelecionada? local) {
    final cidade = local?.cidade?.trim() ?? '';
    final uf = normalizarUf(local?.estado);
    return cidade.length >= 2 && uf != null ? CidadeCampus(cidade, uf) : null;
  }

  bool mesmaCidade(CidadeCampus outra) =>
      normalizarDestino(cidade) == normalizarDestino(outra.cidade) &&
      uf == outra.uf;
}

class CampusDestino {
  final int idCampus;
  final int idInstituicao;
  final String nome;
  final String? sigla;
  final String campus;
  final CidadeCampus cidade;
  final LatLng? ponto;

  const CampusDestino({
    required this.idCampus,
    required this.idInstituicao,
    required this.nome,
    required this.campus,
    required this.cidade,
    this.sigla,
    this.ponto,
  });

  String get titulo =>
      '${sigla?.trim().isNotEmpty == true ? sigla : nome} · $campus';

  bool corresponde(String termo) {
    final palavras = normalizarDestino(
      termo,
    ).split(' ').where((p) => p.isNotEmpty);
    final texto = normalizarDestino(
      '$nome ${sigla ?? ''} $campus ${cidade.cidade} ${cidade.uf}',
    );
    return palavras.every(texto.contains);
  }

  LocalizacaoSelecionada? get localizacao => ponto == null
      ? null
      : LocalizacaoSelecionada(
          ponto: ponto!,
          nome: titulo,
          endereco: '${cidade.cidade}, ${cidade.uf}, Brasil',
          cidade: cidade.cidade,
          estado: CidadeCampus.estados[cidade.uf],
          pais: 'Brasil',
        );

  bool mesmoLocal(LocalizacaoSelecionada local) {
    if (ponto == null) return false;
    final nomeLocal = normalizarDestino(
      local.nome ?? '',
    ).replaceAll(RegExp(r'[^a-z0-9]'), '');
    final nomes = [
      nome,
      sigla ?? '',
      titulo,
    ].map((n) => normalizarDestino(n).replaceAll(RegExp(r'[^a-z0-9]'), ''));
    return nomeLocal.isNotEmpty &&
        nomes.contains(nomeLocal) &&
        const Distance().as(LengthUnit.Meter, ponto!, local.ponto) <= 350;
  }

  factory CampusDestino.fromJson(Map<String, dynamic> json) {
    String texto(String campo) {
      final valor = json[campo];
      if (valor is! String || valor.trim().isEmpty) {
        throw const FormatException('Campus inválido');
      }
      return valor.trim();
    }

    final id = json['idCampus'];
    final instituicao = json['idInstituicao'];
    if (id is! int || id <= 0 || instituicao is! int || instituicao <= 0) {
      throw const FormatException('Identificador de campus inválido');
    }
    final uf = CidadeCampus.normalizarUf(texto('uf'));
    if (uf == null) throw const FormatException('UF inválida');
    final latitude = json['latitude'];
    final longitude = json['longitude'];
    LatLng? ponto;
    if (latitude != null || longitude != null) {
      if (latitude is! num ||
          longitude is! num ||
          !latitude.isFinite ||
          !longitude.isFinite ||
          latitude < -90 ||
          latitude > 90 ||
          longitude < -180 ||
          longitude > 180) {
        throw const FormatException('Coordenadas de campus inválidas');
      }
      ponto = LatLng(latitude.toDouble(), longitude.toDouble());
    }
    final sigla = json['sigla'];
    if (sigla != null && sigla is! String) {
      throw const FormatException('Sigla inválida');
    }
    return CampusDestino(
      idCampus: id,
      idInstituicao: instituicao,
      nome: texto('nome'),
      sigla: sigla as String?,
      campus: texto('campus'),
      cidade: CidadeCampus(texto('municipio'), uf),
      ponto: ponto,
    );
  }
}
