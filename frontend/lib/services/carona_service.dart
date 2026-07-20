import 'dart:convert'; // Permite converter JSON para objetos Dart e vice-versa
import 'package:http/http.dart'
    as http; // Permite fazer requisições HTTP ao backend
import '../config/api_config.dart'; // Importa a URL base da API
import 'auth_service.dart'; // Importa o token do usuário logado

class CaronaService {
  // Busca todas as caronas disponíveis no backend
  static Future<Map<String, dynamic>> listarCaronas() async {
    try {
      // Monta a URL da rota GET /caronas
      final url = Uri.parse('${ApiConfig.baseUrl}/caronas');

      // Faz a requisição ao backend
      final resposta = await http.get(url);
      print('URL CHAMADA: $url');
      print('STATUS: ${resposta.statusCode}');
      print('BODY: ${resposta.body}');

      // Converte a resposta para JSON
      final Map<String, dynamic> dados = resposta.body.isNotEmpty
          ? jsonDecode(resposta.body)
          : {};

      // Verifica se a requisição foi realizada com sucesso
      if (resposta.statusCode == 200) {
        return {'sucesso': true, 'dados': dados};
      }

      // Caso ocorra algum erro retornado pelo backend
      return {
        'sucesso': false,
        'mensagem':
            dados['mensagem'] ?? dados['message'] ?? 'Erro ao buscar caronas',
      };
    } catch (erro) {
      // Caso o backend esteja desligado ou haja erro de conexão
      return {
        'sucesso': false,
        'mensagem': 'Não foi possível conectar ao servidor',
      };
    }
  }

  // Cria uma nova oferta de carona no backend
  static Future<Map<String, dynamic>> criarCarona({
    required String origem,
    required String destino,
    required String dataInicio,
    String? dataFim,
    required String horario,
    required int vagas,
    required double valor,
    required bool recorrente,
    List<String>? diasSemana,
    String? observacoes,
  }) async {
    try {
      // Pega o token JWT salvo após o login
      final token = AuthService.tokenUsuarioLogado;

      // Se não existir token, o usuário não está logado
      if (token == null) {
        return {'sucesso': false, 'mensagem': 'Usuário não está logado'};
      }

      // Monta a URL da rota POST /caronas
      final url = Uri.parse('${ApiConfig.baseUrl}/caronas');

      // Faz a requisição enviando o token no cabeçalho Authorization
      final resposta = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'origem': origem,
          'destino': destino,
          'dataInicio': dataInicio,
          'dataFim': dataFim,
          'horario': horario,
          'vagas': vagas,
          'valor': valor,
          'recorrente': recorrente,
          'diasSemana': diasSemana,
          'observacoes': observacoes,
        }),
      );

      // Converte a resposta do backend para Map
      final Map<String, dynamic> dados = resposta.body.isNotEmpty
          ? jsonDecode(resposta.body)
          : {};

      // Verifica se a carona foi criada com sucesso
      if (resposta.statusCode == 200 || resposta.statusCode == 201) {
        return {'sucesso': true, 'dados': dados};
      }

      // Caso o backend retorne algum erro tratado
      return {
        'sucesso': false,
        'mensagem':
            dados['mensagem'] ?? dados['message'] ?? 'Erro ao criar carona',
      };
    } catch (erro) {
      // Caso o backend esteja desligado ou haja erro inesperado
      return {
        'sucesso': false,
        'mensagem': 'Não foi possível conectar ao servidor',
      };
    }
  }
}
