import 'package:geocoding/geocoding.dart'; // Permite converter coordenadas em endereco

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

      // Junta apenas as partes que existem
      final partes = [
        rua,
        bairro,
        cidade,
        estado,
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
}