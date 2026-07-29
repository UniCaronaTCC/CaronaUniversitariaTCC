import 'dart:convert';

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
      final locais = await placemarkFromCoordinates(latitude, longitude);

      if (locais.isEmpty) {
        return null;
      }

      final local = locais.first;

      final rua = local.street;
      final bairro = local.subLocality;
      final cidade = local.locality?.isNotEmpty == true
          ? local.locality
          : local.subAdministrativeArea;
      final estado = local.administrativeArea;
      final pais = local.country;

      final partes = [
        rua,
        bairro,
        cidade,
        estado,
        pais,
      ].where((parte) => parte != null && parte.isNotEmpty).join(', ');

      if (partes.isEmpty) {
        return null;
      }

      return LocalizacaoSelecionada(
        ponto: LatLng(latitude, longitude),
        endereco: partes,
        cidade: cidade,
      );
    } catch (erro) {
      debugPrint('Erro ao identificar localização: $erro');
      return null;
    }
  }

  Future<List<LocalizacaoSelecionada>> buscarLocalizacoesPorEndereco(
      String enderecoDigitado,
      ) async {
    try {
      final textoBusca = enderecoDigitado.trim();

      if (textoBusca.isEmpty) {
        return [];
      }

      final uri = Uri.https('photon.komoot.io', '/api', {
        'q': textoBusca,
        'limit': '5',
      });

      final response = await http.get(
        uri,
        headers: {'User-Agent': 'UniCarona/1.0'},
      );

      if (response.statusCode != 200) {
        debugPrint('Erro Photon: ${response.statusCode}');
        return [];
      }

      final json = jsonDecode(response.body);

      final features = (json['features'] as List).where((feature) {
        final properties = feature['properties'];
        return (properties['countrycode'] ?? '').toString().toUpperCase() ==
            'BR';
      }).toList();

      return features.map((feature) {
        final properties = feature['properties'];

        final nome = properties['name'] ?? '';

        final rua = properties['street'] ?? '';

        final bairro = properties['district'] ?? '';

        final cidade =
            properties['city'] ??
                properties['locality'] ??
                properties['county'] ??
                '';

        final estado = properties['state'] ?? '';

        final pais = properties['country'] ?? '';

        final coordinates = feature['geometry']['coordinates'];

        final endereco = [
          rua,
          bairro,
          cidade,
          estado,
          pais,
        ].where((item) => item.isNotEmpty).join(', ');

        return LocalizacaoSelecionada(
          ponto: LatLng(coordinates[1], coordinates[0]),
          nome: nome,
          endereco: endereco.isEmpty ? nome : endereco,
          cidade: cidade.toString(),
        );
      }).toList();
    } catch (erro) {
      debugPrint('Erro Photon: $erro');
      return [];
    }
  }
}