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
      final locais = await placemarkFromCoordinates(
        latitude,
        longitude,
      );

      if (locais.isEmpty) {
        return null;
      }

      final local = locais.first;

      final rua = local.street?.trim();
      final bairro = local.subLocality?.trim();

      final cidade = local.locality?.trim().isNotEmpty == true
          ? local.locality!.trim()
          : local.subAdministrativeArea?.trim();

      final estado = local.administrativeArea?.trim();
      final pais = local.country?.trim();

      // Monta o endereço evitando informações repetidas.
      final partes = <String>[];

      void adicionarParte(String? parte) {
        if (parte == null || parte.isEmpty) {
          return;
        }

        final jaExiste = partes.any(
              (existente) =>
          existente.toLowerCase() == parte.toLowerCase(),
        );

        if (!jaExiste) {
          partes.add(parte);
        }
      }

      adicionarParte(rua);
      adicionarParte(bairro);
      adicionarParte(cidade);
      adicionarParte(estado);
      adicionarParte(pais);

      if (partes.isEmpty) {
        return null;
      }

      return LocalizacaoSelecionada(
        ponto: LatLng(latitude, longitude),
        endereco: partes.join(', '),
        cidade: cidade,
        estado: estado,
        pais: pais,
      );
    } catch (erro) {
      debugPrint(
        'Erro ao identificar localização: $erro',
      );

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

      if (response.statusCode != 200) {
        debugPrint(
          'Erro Photon: ${response.statusCode}',
        );

        return [];
      }

      final json = jsonDecode(response.body);

      final features = (json['features'] as List).where(
            (feature) {
          final properties = feature['properties'];

          return (properties['countrycode'] ?? '')
              .toString()
              .toUpperCase() ==
              'BR';
        },
      ).toList();

      return features.map<LocalizacaoSelecionada>(
            (feature) {
          final properties = feature['properties'];

          final nome = properties['name']?.toString().trim() ?? '';

          final rua = properties['street']?.toString().trim();

          final bairro = properties['district']?.toString().trim();

          final cidade = (
              properties['city'] ??
                  properties['locality'] ??
                  properties['county'] ??
                  ''
          ).toString().trim();

          final estado = properties['state']?.toString().trim();

          final pais = properties['country']?.toString().trim();

          final coordinates =
          feature['geometry']['coordinates'];

          // Monta o endereço evitando repetições.
          final partes = <String>[];

          void adicionarParte(String? parte) {
            if (parte == null || parte.isEmpty) {
              return;
            }

            final jaExiste = partes.any(
                  (existente) =>
              existente.toLowerCase() ==
                  parte.toLowerCase(),
            );

            if (!jaExiste) {
              partes.add(parte);
            }
          }

          adicionarParte(rua);
          adicionarParte(bairro);
          adicionarParte(cidade);
          adicionarParte(estado);
          adicionarParte(pais);

          final endereco = partes.join(', ');

          return LocalizacaoSelecionada(
            ponto: LatLng(
              coordinates[1],
              coordinates[0],
            ),
            nome: nome,
            endereco: endereco.isEmpty ? nome : endereco,
            cidade: cidade.isEmpty ? null : cidade,
            estado: estado,
            pais: pais,
          );
        },
      ).toList();
    } catch (erro) {
      debugPrint(
        'Erro Photon: $erro',
      );

      return [];
    }
  }
}