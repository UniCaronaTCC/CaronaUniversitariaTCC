import 'dart:convert'; // Permite converter JSON para objetos Dart e vice-versa
import 'package:http/http.dart' as http; // Permite fazer requisições HTTP ao backend
import '../config/api_config.dart'; // Importa a URL base da API

class CaronaService {

  // Busca todas as caronas disponíveis no backend
  static Future<Map<String, dynamic>> listarCaronas() async {
    try {

      // Monta a URL da rota GET /caronas
      final url = Uri.parse('${ApiConfig.baseUrl}/caronas');

      // Faz a requisição ao backend
      final resposta = await http.get(url);

      // Converte a resposta para JSON
      final Map<String, dynamic> dados = resposta.body.isNotEmpty
          ? jsonDecode(resposta.body)
          : {};

      // Verifica se a requisição foi realizada com sucesso
      if (resposta.statusCode == 200) {
        return {
          'sucesso': true,
          'dados': dados,
        };
      }

      // Caso ocorra algum erro retornado pelo backend
      return {
        'sucesso': false,
        'mensagem': dados['mensagem'] ?? 'Erro ao buscar caronas',
      };

    } catch (erro) {

      // Caso o backend esteja desligado ou haja erro de conexão
      return {
        'sucesso': false,
        'mensagem': 'Não foi possível conectar ao servidor',
      };
    }
  }
}