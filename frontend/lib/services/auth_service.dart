import 'dart:convert'; // Permite converter os dados para JSON e ler respostas em JSON

import 'package:http/http.dart' as http; // Importa o pacote http para fazer requisições ao backend

class AuthService { // Classe responsável pela comunicação de autenticação com o backend

  // URL base do backend
  // No emulador Android, usamos 10.0.2.2 para acessar o localhost do computador
  static const String baseUrl = 'http://10.0.2.2:3000';

  // Função responsável por enviar e-mail e senha para o backend
  static Future<Map<String, dynamic>> fazerLogin(String email, String senha) async {

    // Monta o endereço completo da rota de login do backend
    final url = Uri.parse('$baseUrl/auth/login');

    // Faz uma requisição POST para o backend enviando os dados do login
    final resposta = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json', // Informa que os dados enviados estão em formato JSON
      },
      body: jsonEncode({
        'email': email, // Envia o e-mail digitado pelo usuário
        'senha': senha, // Envia a senha digitada pelo usuário
      }),
    );

    // Converte a resposta do backend de JSON para Map
    final dados = jsonDecode(resposta.body);

    // Verifica se o backend respondeu com sucesso
    if (resposta.statusCode == 200 || resposta.statusCode == 201) {
      return {
        'sucesso': true, // Indica que o login deu certo
        'dados': dados, // Guarda os dados retornados pelo backend
      };
    }

    // Caso o backend retorne erro, envia a mensagem de erro para a tela
    return {
      'sucesso': false, // Indica que o login falhou
      'mensagem': dados['message'] ?? 'Erro ao fazer login', // Mensagem que será exibida ao usuário
    };
  }
}