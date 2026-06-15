import 'dart:convert'; // Permite converter os dados para JSON e ler respostas em JSON
import 'package:http/http.dart' as http; // Importa o pacote http para fazer requisições ao backend
import '../config/api_config.dart'; // Importa a URL base do backend

class AuthService { // Classe responsável pela comunicação de autenticação com o backend

  // Função responsável por enviar e-mail e senha para o backend
  static Future<Map<String, dynamic>> fazerLogin(String email, String senha) async {
    try { // Tenta executar a requisição normalmente

      // Monta o endereço completo da rota de login do backend
      final url = Uri.parse('${ApiConfig.baseUrl}/auth/login');

      // Faz uma requisição POST para o backend enviando os dados do login
      final resposta = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'email': email,
          'senha': senha,
        }),
      );

      // Converte a resposta do backend de JSON para Map
      // Se a resposta vier vazia, usa um Map vazio para evitar erro
      final Map<String, dynamic> dados = resposta.body.isNotEmpty
          ? jsonDecode(resposta.body)
          : {};

      // Verifica se o backend respondeu com sucesso
      if (resposta.statusCode == 200 || resposta.statusCode == 201) {
        return {
          'sucesso': true,
          'dados': dados,
        };
      }

      // Caso o backend retorne erro
      // Usa 'mensagem' se existir, senão usa 'message', que é comum nos erros do NestJS
      return {
        'sucesso': false,
        'mensagem': dados['mensagem'] ?? dados['message'] ?? 'Erro ao fazer login',
      };
    } catch (erro) { // Captura erro de conexão, backend desligado ou resposta inesperada

      // Retorna uma mensagem amigável para o app não quebrar
      return {
        'sucesso': false,
        'mensagem': 'Não foi possível conectar ao servidor',
      };
    }
  }

  // Função responsável por enviar nome, e-mail e senha para o backend
  static Future<Map<String, dynamic>> fazerCadastro(
      String nome,
      String email,
      String senha,
      ) async {
    try { // Tenta executar a requisição normalmente

      // Monta o endereço completo da rota de cadastro do backend
      final url = Uri.parse('${ApiConfig.baseUrl}/auth/cadastro');

      // Faz uma requisição POST para o backend enviando os dados do cadastro
      final resposta = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'nome': nome,
          'email': email,
          'senha': senha,
        }),
      );

      // Converte a resposta do backend de JSON para Map
      // Se a resposta vier vazia, usa um Map vazio para evitar erro
      final Map<String, dynamic> dados = resposta.body.isNotEmpty
          ? jsonDecode(resposta.body)
          : {};

      // Verifica se o backend respondeu com sucesso
      if (resposta.statusCode == 200 || resposta.statusCode == 201) {
        return {
          'sucesso': true,
          'dados': dados,
        };
      }

      // Caso o backend retorne erro
      // Usa 'mensagem' se existir, senão usa 'message', que é comum nos erros do NestJS
      return {
        'sucesso': false,
        'mensagem': dados['mensagem'] ?? dados['message'] ?? 'Erro ao cadastrar',
      };
    } catch (erro) { // Captura erro de conexão, backend desligado ou resposta inesperada

      // Retorna uma mensagem amigável para o app não quebrar
      return {
        'sucesso': false,
        'mensagem': 'Não foi possível conectar ao servidor',
      };
    }
  }
}