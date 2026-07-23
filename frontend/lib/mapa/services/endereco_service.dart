import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:geocoding/geocoding.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../models/localizacao_selecionada.dart';

class EnderecoService {
  Future<String> buscarEnderecoPorCoordenadas(
    double latitude,
    double longitude,
  ) async {
    try {
      final locais = await placemarkFromCoordinates(latitude, longitude);

      if (locais.isEmpty) {
        return 'Endereço não encontrado';
      }

      final local = locais.first;

      final rua = local.street;
      final bairro = local.subLocality;
      final cidade = local.locality;
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
        return 'Endereço não encontrado';
      }

      return partes;
    } catch (erro) {
      return 'Erro ao buscar endereço';
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

      final json = jsonDecode(response.body);

      final features = json['features'] as List;

      return features.map((feature) {
        final properties = feature['properties'];

        final coordinates = feature['geometry']['coordinates'];

        return LocalizacaoSelecionada(
          ponto: LatLng(coordinates[1], coordinates[0]),
          endereco: properties['name'] ?? '',
        );
      }).toList();
    } catch (erro) {
      debugPrint('Erro Photon: $erro');
      return [];
    }
  }
}
