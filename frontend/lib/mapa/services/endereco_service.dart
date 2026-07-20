import 'package:geocoding/geocoding.dart'; // Permite converter endereco em coordenadas e coordenadas em endereco
import 'package:latlong2/latlong.dart'; // Permite guardar latitude e longitude

import '../models/localizacao_selecionada.dart'; // Model com ponto e endereco escolhido

class EnderecoService {
  // Converte latitude e longitude em um texto de endereco
  Future<String> buscarEnderecoPorCoordenadas(
      double latitude,
      double longitude,
      ) async {
    try {
      // Busca informacoes do local a partir das coordenadas
      final locais = await placemarkFromCoordinates(
        latitude,
        longitude,
      );

      // Se nao encontrar nenhum endereco, retorna texto padrao
      if (locais.isEmpty) {
        return 'Endereco nao encontrado';
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
        return 'Endereco nao encontrado';
      }

      return partes;
    } catch (erro) {
      // Caso aconteca erro na conversao
      return 'Erro ao buscar endereco';
    }
  }

  // Busca possiveis localizacoes a partir de um endereco ou nome digitado
  Future<List<LocalizacaoSelecionada>> buscarLocalizacoesPorEndereco(
      String enderecoDigitado,
      ) async {
    try {
      // Remove espacos desnecessarios
      final textoBusca = enderecoDigitado.trim();

      // Se o usuario nao digitou nada, retorna lista vazia
      if (textoBusca.isEmpty) {
        return [];
      }

      // Adiciona Brasil para reduzir chance de cair em outro pais
      final busca = '$textoBusca, Brasil';

      // Busca coordenadas possiveis para o endereco digitado
      final localizacoes = await locationFromAddress(busca);

      // Lista que vai guardar os resultados completos
      final resultados = <LocalizacaoSelecionada>[];

      // Para cada coordenada encontrada, busca o endereco completo
      for (final localizacao in localizacoes) {
        final enderecoCompleto = await buscarEnderecoPorCoordenadas(
          localizacao.latitude,
          localizacao.longitude,
        );

        resultados.add(
          LocalizacaoSelecionada(
            ponto: LatLng(
              localizacao.latitude,
              localizacao.longitude,
            ),
            endereco: enderecoCompleto,
          ),
        );
      }

      return resultados;
    } catch (erro) {
      // Caso nao encontre ou aconteca erro, retorna lista vazia
      return [];
    }
  }
}