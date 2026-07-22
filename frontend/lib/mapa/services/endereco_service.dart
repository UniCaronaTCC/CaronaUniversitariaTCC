import 'dart:convert';

import 'package:geocoding/geocoding.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../models/localizacao_selecionada.dart';

import 'package:flutter/foundation.dart';
class EnderecoService {
  // Converte latitude e longitude em um texto de endereco
  Future<String> buscarEnderecoPorCoordenadas(
    double latitude,
    double longitude,
  ) async {
    try {
      // Busca informacoes do local a partir das coordenadas
      final locais = await placemarkFromCoordinates(latitude, longitude);

      // Se nao encontrar nenhum endereco, retorna texto padrao
      if (locais.isEmpty) {
        return 'Endereço não encontrado';
      }

      // Pega o primeiro resultado encontrado
      final local = locais.first;

      // Monta partes do endereco
      final rua = local.street;
      final bairro = local.subLocality;
      final cidade = local.locality;
      final estado = local.administrativeArea;
      final pais = local.country;

      // Junta apenas as partes que existem
      final partes = [
        rua,
        bairro,
        cidade,
        estado,
        pais,
      ].where((parte) => parte != null && parte.isNotEmpty).join(', ');

      // Se nao tiver partes suficientes, retorna texto padrao
      if (partes.isEmpty) {
        return 'Endereço não encontrado';
      }

      return partes;
    } catch (erro) {
      // Caso aconteca erro na conversao
      return 'Erro ao buscar endereço';
    }
  }

  // Busca possiveis localizacoes a partir de um endereco ou nome digitado
  Future<List<LocalizacaoSelecionada>> buscarLocalizacoesPorEndereco(
    String enderecoDigitado,
  ) async {
    try {
      final textoBusca = enderecoDigitado.trim();

      if (textoBusca.isEmpty) {
        return [];
      }

      final uri = Uri.https(
        'photon.komoot.io',
        '/api',
        {
          'q': textoBusca,
          'limit': '5',
        },
      );

      final response = await http.get(
        uri,
        headers: {
          'User-Agent': 'UniCarona/1.0',
        },
      );

      final json = jsonDecode(response.body);

      final features = json['features'] as List;

      return features.map((feature) {
        final properties = feature['properties'];

        final coordinates = feature['geometry']['coordinates'];

        return LocalizacaoSelecionada(
          ponto: LatLng(
            coordinates[1],
            coordinates[0],
          ),
          endereco: properties['name'] ?? '',
        );
      }).toList();

      return [];
    } catch (erro) {
      debugPrint('Erro Photon: $erro');
      return [];
    }
  }
}
