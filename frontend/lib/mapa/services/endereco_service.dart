import 'dart:async';
import 'dart:convert';

import 'package:diacritic/diacritic.dart';
import 'package:flutter/foundation.dart';
import 'package:geocoding/geocoding.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../../services/cliente_http_com_prazo.dart';
import '../models/localizacao_selecionada.dart';
import '../models/consulta_endereco.dart';

enum TipoFalhaEndereco {
  conexao,
  tempoEsgotado,
  limite,
  indisponivel,
  respostaInvalida,
}

class FalhaBuscaEndereco implements Exception {
  final TipoFalhaEndereco tipo;
  const FalhaBuscaEndereco(this.tipo);

  String get mensagem => switch (tipo) {
    TipoFalhaEndereco.conexao =>
      'Não foi possível consultar os endereços. Confira a conexão e tente novamente.',
    TipoFalhaEndereco.tempoEsgotado =>
      'A busca de endereços demorou demais. Tente novamente.',
    TipoFalhaEndereco.limite =>
      'Muitas consultas de endereço. Aguarde um momento antes de tentar novamente.',
    TipoFalhaEndereco.indisponivel =>
      'A busca de endereços está indisponível agora. Tente novamente.',
    TipoFalhaEndereco.respostaInvalida =>
      'Não foi possível interpretar a resposta da busca de endereços. Tente novamente.',
  };

  static String mensagemPara(Object erro) => erro is FalhaBuscaEndereco
      ? erro.mensagem
      : const FalhaBuscaEndereco(TipoFalhaEndereco.indisponivel).mensagem;
}

class EnderecoService {
  final http.Client? cliente;
  final Duration prazo;

  EnderecoService({this.cliente, this.prazo = const Duration(seconds: 8)});

  Future<LocalizacaoSelecionada?> buscarLocalizacaoPorCoordenadas(
    double latitude,
    double longitude,
  ) async {
    try {
      final locais = await placemarkFromCoordinates(latitude, longitude);

      if (locais.isEmpty) {
        return null;
      }

      final local = locais.first;

      final cidade = local.locality?.trim().isNotEmpty == true
          ? local.locality!.trim()
          : local.subAdministrativeArea?.trim();

      final endereco = _montarEndereco([
        local.street,
        local.subThoroughfare,
        local.subLocality,
        cidade,
        local.administrativeArea,
        local.country,
      ]);

      if (endereco.isEmpty) {
        return null;
      }

      return LocalizacaoSelecionada(
        ponto: LatLng(latitude, longitude),
        endereco: endereco,
        cidade: cidade,
        estado: local.administrativeArea?.trim(),
        pais: local.country?.trim(),
        pontoEspecifico: true,
      );
    } catch (erro) {
      debugPrint('Erro ao identificar localização: $erro');
      return null;
    }
  }

  Future<List<LocalizacaoSelecionada>> buscarLocalizacoesPorEndereco(
    String enderecoDigitado, {
    double? latitudeReferencia,
    double? longitudeReferencia,
    String? cidadeReferencia,
    String? estadoReferencia,
  }) async {
    final textoBusca = enderecoDigitado.trim();

    if (textoBusca.length < 3) {
      return [];
    }

    final referenciaValida =
        latitudeReferencia != null &&
        longitudeReferencia != null &&
        latitudeReferencia.isFinite &&
        longitudeReferencia.isFinite &&
        latitudeReferencia >= -90 &&
        latitudeReferencia <= 90 &&
        longitudeReferencia >= -180 &&
        longitudeReferencia <= 180;
    final latitude = referenciaValida ? latitudeReferencia : null;
    final longitude = referenciaValida ? longitudeReferencia : null;
    var resultados = await _buscarNoPhoton(
      textoBusca,
      latitudeReferencia: latitude,
      longitudeReferencia: longitude,
    );

    final numeroNoNomeDaRua =
        !textoBusca.contains(',') &&
        resultados.any(
          (local) =>
              local.precisao == PrecisaoLocalizacao.rua &&
              ConsultaEndereco.normalizarLogradouro(local.rua ?? '') ==
                  ConsultaEndereco.normalizarLogradouro(textoBusca),
        );
    final consulta = ConsultaEndereco(
      textoBusca,
      interpretarNumero: !numeroNoNomeDaRua,
    );
    final buscaAlternativa =
        consulta.semNumero ??
        (consulta.logradouro == null
            ? _prepararBuscaAlternativa(textoBusca)
            : '');
    final numeroEncontrado =
        consulta.numero != null &&
        resultados.any(
          (local) =>
              ConsultaEndereco.normalizarLogradouro(local.rua ?? '') ==
                  ConsultaEndereco.normalizarLogradouro(consulta.logradouro!) &&
              local.numero?.trim().toUpperCase() == consulta.numero,
        );

    // Exemplo: "mc donalds" faz uma segunda tentativa como "mcdonalds".
    if ((consulta.numero != null ? !numeroEncontrado : resultados.length < 3) &&
        buscaAlternativa.isNotEmpty &&
        buscaAlternativa != _normalizar(textoBusca)) {
      try {
        final alternativos = await _buscarNoPhoton(
          buscaAlternativa,
          latitudeReferencia: latitude,
          longitudeReferencia: longitude,
        );
        resultados = _juntarSemDuplicar(resultados, alternativos);
      } on FalhaBuscaEndereco {
        // Uma falha complementar nao apaga sugestoes ja recebidas.
        if (resultados.isEmpty) rethrow;
      }
    }

    resultados = _juntarSemDuplicar(resultados, []);
    final indexados = resultados.asMap().entries.toList();
    indexados.sort((a, b) {
      final comparacao =
          _calcularPrioridade(
            local: b.value,
            textoBusca: textoBusca,
            consulta: consulta,
            cidadeReferencia: cidadeReferencia,
            estadoReferencia: estadoReferencia,
            latitudeReferencia: latitude,
            longitudeReferencia: longitude,
          ).compareTo(
            _calcularPrioridade(
              local: a.value,
              textoBusca: textoBusca,
              consulta: consulta,
              cidadeReferencia: cidadeReferencia,
              estadoReferencia: estadoReferencia,
              latitudeReferencia: latitude,
              longitudeReferencia: longitude,
            ),
          );
      return comparacao != 0 ? comparacao : a.key.compareTo(b.key);
    });

    return indexados
        .take(5)
        .map(
          (item) => consulta.numero == null
              ? item.value
              : item.value.comNumeroBuscado(
                  consulta.numero!,
                  logradouroBuscado: consulta.logradouro,
                ),
        )
        .toList();
  }

  Future<List<LocalizacaoSelecionada>> _buscarNoPhoton(
    String textoBusca, {
    double? latitudeReferencia,
    double? longitudeReferencia,
  }) async {
    final parametros = <String, String>{
      'q': textoBusca,
      'limit': '15',
      'countrycode': 'BR',
    };

    if (latitudeReferencia != null && longitudeReferencia != null) {
      parametros['lat'] = latitudeReferencia.toString();
      parametros['lon'] = longitudeReferencia.toString();
    }

    final url = Uri.https('photon.komoot.io', '/api', parametros);
    final headers = {'User-Agent': 'UniCarona/1.0'};
    final conexao = cliente ?? ClienteHttpComPrazo(prazo: prazo);
    try {
      final resposta = await conexao.get(url, headers: headers).timeout(prazo);
      if (resposta.statusCode == 429) {
        throw const FalhaBuscaEndereco(TipoFalhaEndereco.limite);
      }
      if (resposta.statusCode != 200) {
        throw const FalhaBuscaEndereco(TipoFalhaEndereco.indisponivel);
      }
      final json = jsonDecode(utf8.decode(resposta.bodyBytes));
      if (json is! Map || json['features'] is! List) {
        throw const FalhaBuscaEndereco(TipoFalhaEndereco.respostaInvalida);
      }
      return (json['features'] as List)
          .map(_converterFeaturePhoton)
          .whereType<LocalizacaoSelecionada>()
          .toList();
    } on FalhaBuscaEndereco {
      rethrow;
    } on TimeoutException {
      throw const FalhaBuscaEndereco(TipoFalhaEndereco.tempoEsgotado);
    } on http.ClientException {
      throw const FalhaBuscaEndereco(TipoFalhaEndereco.conexao);
    } on FormatException {
      throw const FalhaBuscaEndereco(TipoFalhaEndereco.respostaInvalida);
    } catch (_) {
      throw const FalhaBuscaEndereco(TipoFalhaEndereco.indisponivel);
    } finally {
      if (cliente == null) conexao.close();
    }
  }

  LocalizacaoSelecionada? _converterFeaturePhoton(dynamic feature) {
    if (feature is! Map) {
      return null;
    }

    final properties = feature['properties'];
    final geometry = feature['geometry'];

    if (properties is! Map || geometry is! Map) {
      return null;
    }

    final paisCodigo =
        properties['countrycode']?.toString().toUpperCase() ?? '';

    if (paisCodigo != 'BR') {
      return null;
    }

    final coordinates = geometry['coordinates'];

    if (coordinates is! List || coordinates.length < 2) {
      return null;
    }

    final longitude = double.tryParse(coordinates[0].toString());

    final latitude = double.tryParse(coordinates[1].toString());

    if (latitude == null ||
        longitude == null ||
        !latitude.isFinite ||
        !longitude.isFinite ||
        latitude < -90 ||
        latitude > 90 ||
        longitude < -180 ||
        longitude > 180) {
      return null;
    }

    final nome = properties['name']?.toString().trim() ?? '';

    final rua = properties['street']?.toString().trim() ?? '';
    final numero = properties['housenumber']?.toString().trim() ?? '';
    final tipo = properties['type']?.toString().toLowerCase().trim() ?? '';
    final osmKey = properties['osm_key']?.toString().toLowerCase() ?? '';
    final osmValue = properties['osm_value']?.toString().toLowerCase() ?? '';
    const tiposGenericos = {
      'city',
      'town',
      'village',
      'municipality',
      'county',
      'state',
      'country',
      'locality',
      'district',
      'suburb',
      'neighbourhood',
      'hamlet',
      'borough',
    };
    final PrecisaoLocalizacao precisao;
    if (tiposGenericos.contains(tipo) ||
        (osmKey == 'place' && tiposGenericos.contains(osmValue)) ||
        osmKey == 'boundary') {
      precisao = PrecisaoLocalizacao.regiao;
    } else if (rua.isNotEmpty && numero.isNotEmpty) {
      precisao = PrecisaoLocalizacao.ponto;
    } else if (tipo == 'street' || osmKey == 'highway') {
      precisao = PrecisaoLocalizacao.rua;
    } else if (tipo == 'house' ||
        tipo == 'building' ||
        (nome.isNotEmpty &&
            const {
              'amenity',
              'shop',
              'office',
              'tourism',
              'leisure',
              'healthcare',
              'building',
              'historic',
              'railway',
              'aeroway',
            }.contains(osmKey))) {
      precisao = PrecisaoLocalizacao.ponto;
    } else {
      precisao = PrecisaoLocalizacao.desconhecida;
    }
    final pontoEspecifico = precisao == PrecisaoLocalizacao.ponto;
    final logradouro = rua.isNotEmpty
        ? rua
        : precisao == PrecisaoLocalizacao.rua
        ? nome
        : '';

    final cidade =
        (properties['city'] ??
                ((tipo == 'city' ||
                            (osmKey == 'place' &&
                                const {
                                  'city',
                                  'town',
                                  'municipality',
                                  'village',
                                }.contains(osmValue))) &&
                        nome.isNotEmpty
                    ? nome
                    : null) ??
                properties['locality'] ??
                properties['county'] ??
                '')
            .toString()
            .trim();

    final estado = properties['state']?.toString().trim();

    final pais = properties['country']?.toString().trim();

    final endereco = _montarEndereco([
      logradouro,
      numero,
      properties['district']?.toString(),
      cidade,
      estado,
      pais,
    ]);

    return LocalizacaoSelecionada(
      ponto: LatLng(latitude, longitude),
      nome: nome.isEmpty ? null : nome,
      endereco: endereco.isEmpty ? nome : endereco,
      cidade: cidade.isEmpty ? null : cidade,
      estado: estado,
      pais: pais,
      rua: logradouro.isEmpty ? null : logradouro,
      numero: numero.isEmpty ? null : numero,
      pontoEspecifico: pontoEspecifico,
      precisao: precisao,
    );
  }

  List<LocalizacaoSelecionada> _juntarSemDuplicar(
    List<LocalizacaoSelecionada> primeiraLista,
    List<LocalizacaoSelecionada> segundaLista,
  ) {
    final resultado = <LocalizacaoSelecionada>[];
    for (final local in [...primeiraLista, ...segundaLista]) {
      final indice = resultado.indexWhere(
        (existente) => _mesmoLugar(existente, local),
      );
      if (indice == -1) {
        resultado.add(local);
      } else if (_completudeEndereco(local) >
          _completudeEndereco(resultado[indice])) {
        resultado[indice] = local;
      }
    }

    return resultado;
  }

  bool _mesmoLugar(LocalizacaoSelecionada a, LocalizacaoSelecionada b) {
    final nome = _normalizarCompacto(a.nome ?? '');
    final outroNome = _normalizarCompacto(b.nome ?? '');
    if (nome.isEmpty && outroNome.isEmpty) {
      return a.ponto == b.ponto &&
          _normalizar(a.endereco) == _normalizar(b.endereco);
    }
    if (nome.isEmpty || nome != outroNome) return false;
    for (final par in [
      (a.cidade, b.cidade),
      (a.estado, b.estado),
      (a.rua, b.rua),
      (a.numero, b.numero),
    ]) {
      final primeiro = _normalizar(par.$1 ?? '');
      final segundo = _normalizar(par.$2 ?? '');
      if (primeiro.isNotEmpty && segundo.isNotEmpty && primeiro != segundo) {
        return false;
      }
    }
    // O mesmo campus pode aparecer como ponto e como area no OpenStreetMap.
    return const Distance().as(LengthUnit.Meter, a.ponto, b.ponto) <= 350;
  }

  int _completudeEndereco(LocalizacaoSelecionada local) =>
      (local.numero?.isNotEmpty == true ? 1000 : 0) + local.endereco.length;

  double _calcularPrioridade({
    required LocalizacaoSelecionada local,
    required String textoBusca,
    required ConsultaEndereco consulta,
    String? cidadeReferencia,
    String? estadoReferencia,
    double? latitudeReferencia,
    double? longitudeReferencia,
  }) {
    double prioridade = 0;

    final buscaCompacta = _normalizarCompacto(textoBusca);
    final nomeCompacto = _normalizarCompacto(local.nome ?? '');
    if (buscaCompacta.isNotEmpty && nomeCompacto == buscaCompacta) {
      prioridade += 5000;
    }

    if (consulta.logradouro != null &&
        ConsultaEndereco.normalizarLogradouro(consulta.logradouro!) ==
            ConsultaEndereco.normalizarLogradouro(local.rua ?? '')) {
      prioridade += 4000;
      if (consulta.numero != null) {
        prioridade += local.numero?.trim().toUpperCase() == consulta.numero
            ? 4000
            : local.numero == null || local.numero!.isEmpty
            ? 500
            : -500;
      }
    }

    final palavras = ConsultaEndereco.normalizar(textoBusca)
        .split(' ')
        .where(
          (p) =>
              p.isNotEmpty &&
              !const {
                'rua',
                'r',
                'avenida',
                'av',
                'de',
                'da',
                'do',
                'das',
                'dos',
                'e',
              }.contains(p),
        )
        .toSet();
    final termosLocal = ConsultaEndereco.normalizar(
      '${local.nome ?? ''} ${local.endereco}',
    ).split(' ').toSet();
    if (palavras.isNotEmpty) {
      final correspondencias = palavras
          .where(
            (p) => termosLocal.any(
              (t) => t == p || (p.length >= 3 && t.startsWith(p)),
            ),
          )
          .length;
      prioridade += 1000 * correspondencias / palavras.length;
    }
    // Apenas a cidade completa, fora do nome do logradouro, indica intencao geografica.
    if (consulta.cidadeExplicita(local.cidade ?? '')) prioridade += 12000;

    final cidade = _normalizar(local.cidade ?? '');
    final estado = _normalizar(local.estado ?? '');

    final cidadeEsperada = _normalizar(cidadeReferencia ?? '');

    if (cidadeEsperada.isNotEmpty && cidade == cidadeEsperada) {
      prioridade += 200;
    }

    final estadoEsperado = _normalizar(estadoReferencia ?? '');

    if (estadoEsperado.isNotEmpty && estado == estadoEsperado) {
      prioridade += 50;
    }

    if (latitudeReferencia != null && longitudeReferencia != null) {
      const distancia = Distance();

      final distanciaKm = distancia.as(
        LengthUnit.Kilometer,
        LatLng(latitudeReferencia, longitudeReferencia),
        local.ponto,
      );

      // Proximidade ajuda, mas não passa por cima da cidade pesquisada.
      prioridade += 100 / (1 + distanciaKm);
    }

    return prioridade;
  }

  String _montarEndereco(Iterable<String?> partesRecebidas) {
    final partes = <String>[];

    for (final parteRecebida in partesRecebidas) {
      final parte = parteRecebida?.trim();

      if (parte == null || parte.isEmpty) {
        continue;
      }

      final normalizada = _normalizar(parte);

      final jaExiste = partes.any(
        (existente) => _normalizar(existente) == normalizada,
      );

      if (!jaExiste) {
        partes.add(parte);
      }
    }

    return partes.join(', ');
  }

  String _prepararBuscaAlternativa(String texto) {
    return _normalizarCompacto(texto);
  }

  String _normalizar(String texto) {
    return removeDiacritics(texto).toLowerCase().trim();
  }

  String _normalizarCompacto(String texto) {
    return removeDiacritics(
      texto,
    ).toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
  }
}
