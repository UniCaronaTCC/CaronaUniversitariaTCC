import 'dart:async';
import 'dart:convert';

import 'package:diacritic/diacritic.dart';
import 'package:flutter/foundation.dart';
import 'package:geocoding/geocoding.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../models/localizacao_selecionada.dart';

class EnderecoService {
  Future<LocalizacaoSelecionada?> buscarLocalizacaoPorCoordenadas(
      double latitude,
      double longitude,
      ) async {
    try {
      final locais = await placemarkFromCoordinates(
        latitude,
        longitude,
      );

      if (locais.isEmpty) {
        return null;
      }

      final local = locais.first;

      final cidade = local.locality?.trim().isNotEmpty == true
          ? local.locality!.trim()
          : local.subAdministrativeArea?.trim();

      final endereco = _montarEndereco([
        local.street,
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

    try {
      var resultados = await _buscarNoPhoton(
        textoBusca,
        latitudeReferencia: latitudeReferencia,
        longitudeReferencia: longitudeReferencia,
      );

      final buscaAlternativa = _prepararBuscaAlternativa(textoBusca);

      // Exemplo: "mc donalds" faz uma segunda tentativa como "mcdonalds".
      if (resultados.length < 3 &&
          buscaAlternativa.isNotEmpty &&
          buscaAlternativa != _normalizar(textoBusca)) {
        final alternativos = await _buscarNoPhoton(
          buscaAlternativa,
          latitudeReferencia: latitudeReferencia,
          longitudeReferencia: longitudeReferencia,
        );

        resultados = _juntarSemDuplicar(
          resultados,
          alternativos,
        );
      }

      resultados.sort(
            (a, b) => _calcularPrioridade(
          local: b,
          textoBusca: textoBusca,
          cidadeReferencia: cidadeReferencia,
          estadoReferencia: estadoReferencia,
          latitudeReferencia: latitudeReferencia,
          longitudeReferencia: longitudeReferencia,
        ).compareTo(
          _calcularPrioridade(
            local: a,
            textoBusca: textoBusca,
            cidadeReferencia: cidadeReferencia,
            estadoReferencia: estadoReferencia,
            latitudeReferencia: latitudeReferencia,
            longitudeReferencia: longitudeReferencia,
          ),
        ),
      );

      return resultados.take(5).toList();
    } on TimeoutException {
      debugPrint('Photon demorou demais para responder');
      return [];
    } catch (erro) {
      debugPrint('Erro Photon: $erro');
      return [];
    }
  }

  Future<List<LocalizacaoSelecionada>> _buscarNoPhoton(
      String textoBusca, {
        double? latitudeReferencia,
        double? longitudeReferencia,
      }) async {
    final parametros = <String, String>{
      'q': textoBusca,
      'limit': '15',
    };

    if (latitudeReferencia != null &&
        longitudeReferencia != null) {
      parametros['lat'] = latitudeReferencia.toString();
      parametros['lon'] = longitudeReferencia.toString();
    }

    final resposta = await http
        .get(
      Uri.https(
        'photon.komoot.io',
        '/api',
        parametros,
      ),
      headers: {
        'User-Agent': 'UniCarona/1.0',
      },
    )
        .timeout(
      const Duration(seconds: 8),
    );

    if (resposta.statusCode != 200) {
      debugPrint(
        'Erro Photon: ${resposta.statusCode}',
      );
      return [];
    }

    final json = jsonDecode(resposta.body);
    final features = json['features'];

    if (features is! List) {
      return [];
    }

    return features
        .map(_converterFeaturePhoton)
        .whereType<LocalizacaoSelecionada>()
        .toList();
  }

  LocalizacaoSelecionada? _converterFeaturePhoton(
      dynamic feature,
      ) {
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

    final longitude = double.tryParse(
      coordinates[0].toString(),
    );

    final latitude = double.tryParse(
      coordinates[1].toString(),
    );

    if (latitude == null || longitude == null) {
      return null;
    }

    final nome =
        properties['name']?.toString().trim() ?? '';

    final cidade = (
        properties['city'] ??
            properties['locality'] ??
            properties['county'] ??
            ''
    ).toString().trim();

    final estado =
    properties['state']?.toString().trim();

    final pais =
    properties['country']?.toString().trim();

    final endereco = _montarEndereco([
      properties['street']?.toString(),
      properties['district']?.toString(),
      cidade,
      estado,
      pais,
    ]);

    return LocalizacaoSelecionada(
      ponto: LatLng(
        latitude,
        longitude,
      ),
      nome: nome.isEmpty ? null : nome,
      endereco: endereco.isEmpty ? nome : endereco,
      cidade: cidade.isEmpty ? null : cidade,
      estado: estado,
      pais: pais,
    );
  }

  List<LocalizacaoSelecionada> _juntarSemDuplicar(
      List<LocalizacaoSelecionada> primeiraLista,
      List<LocalizacaoSelecionada> segundaLista,
      ) {
    final resultado = [...primeiraLista];

    for (final local in segundaLista) {
      final jaExiste = resultado.any(
            (existente) =>
        existente.ponto.latitude ==
            local.ponto.latitude &&
            existente.ponto.longitude ==
                local.ponto.longitude,
      );

      if (!jaExiste) {
        resultado.add(local);
      }
    }

    return resultado;
  }

  double _calcularPrioridade({
    required LocalizacaoSelecionada local,
    required String textoBusca,
    String? cidadeReferencia,
    String? estadoReferencia,
    double? latitudeReferencia,
    double? longitudeReferencia,
  }) {
    double prioridade = 0;

    final busca = _normalizar(textoBusca);
    final buscaCompacta = _normalizarCompacto(textoBusca);

    final nome = _normalizar(local.nome ?? '');
    final nomeCompacto = _normalizarCompacto(
      local.nome ?? '',
    );

    final endereco = _normalizar(local.endereco);
    final cidade = _normalizar(local.cidade ?? '');
    final estado = _normalizar(local.estado ?? '');

    final palavras = busca
        .split(RegExp(r'\s+'))
        .where((palavra) => palavra.length >= 3);

    // McDonald's, mc donalds e mcdonalds ficam equivalentes.
    if (buscaCompacta.isNotEmpty &&
        nomeCompacto.isNotEmpty) {
      if (nomeCompacto == buscaCompacta) {
        prioridade += 2000;
      } else if (nomeCompacto.contains(buscaCompacta) ||
          buscaCompacta.contains(nomeCompacto)) {
        prioridade += 1200;
      }
    }

    if (nome.isNotEmpty && nome.contains(busca)) {
      prioridade += 800;
    }

    for (final palavra in palavras) {
      if (nome.contains(palavra)) {
        prioridade += 350;
      }

      // Cidade escrita pelo usuário ganha prioridade alta.
      if (cidade.contains(palavra)) {
        prioridade += 1200;
      }

      if (estado.contains(palavra)) {
        prioridade += 300;
      }

      if (endereco.contains(palavra)) {
        prioridade += 80;
      }
    }

    final cidadeEsperada = _normalizar(
      cidadeReferencia ?? '',
    );

    if (cidadeEsperada.isNotEmpty &&
        cidade == cidadeEsperada) {
      prioridade += 1000;
    }

    final estadoEsperado = _normalizar(
      estadoReferencia ?? '',
    );

    if (estadoEsperado.isNotEmpty &&
        estado == estadoEsperado) {
      prioridade += 300;
    }

    if (latitudeReferencia != null &&
        longitudeReferencia != null) {
      const distancia = Distance();

      final distanciaKm = distancia.as(
        LengthUnit.Kilometer,
        LatLng(
          latitudeReferencia,
          longitudeReferencia,
        ),
        local.ponto,
      );

      // Proximidade ajuda, mas não passa por cima da cidade pesquisada.
      prioridade += 200 / (1 + distanciaKm);
    }

    return prioridade;
  }

  String _montarEndereco(
      Iterable<String?> partesRecebidas,
      ) {
    final partes = <String>[];

    for (final parteRecebida in partesRecebidas) {
      final parte = parteRecebida?.trim();

      if (parte == null || parte.isEmpty) {
        continue;
      }

      final normalizada = _normalizar(parte);

      final jaExiste = partes.any(
            (existente) =>
        _normalizar(existente) == normalizada,
      );

      if (!jaExiste) {
        partes.add(parte);
      }
    }

    return partes.join(', ');
  }

  String _prepararBuscaAlternativa(
      String texto,
      ) {
    return _normalizarCompacto(texto);
  }

  String _normalizar(
      String texto,
      ) {
    return removeDiacritics(texto)
        .toLowerCase()
        .trim();
  }

  String _normalizarCompacto(
      String texto,
      ) {
    return removeDiacritics(texto)
        .toLowerCase()
        .replaceAll(
      RegExp(r'[^a-z0-9]'),
      '',
    );
  }
}