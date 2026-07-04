import 'dart:convert'; // Permite converter os dados para JSON e ler respostas em JSON
import 'package:http/http.dart' as http; // Importa o pacote http para fazer requisições ao backend
import '../config/api_config.dart'; // Importa a URL base do backend

class AuthService { // Classe responsável pela comunicação de autenticação com o backend

  // Guarda o token JWT do usuário logado enquanto o app estiver aberto
  static String? tokenUsuarioLogado;

  // Guarda os dados básicos do usuário logado enquanto o app estiver aberto
  static Map<String, dynamic>? usuarioLogado;

  // Verifica se existe usuário logado no app
  static bool get estaLogado => tokenUsuarioLogado != null;

  // Função responsável por limpar os dados do usuário logado
  static void sair() {
    tokenUsuarioLogado = null;
    usuarioLogado = null;
  }

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

        // Guarda o token JWT retornado pelo backend
        tokenUsuarioLogado = dados['token'];

        // Guarda os dados do usuário retornado pelo backend
        if (dados['usuario'] is Map<String, dynamic>) {
          usuarioLogado = dados['usuario'];
        }

        return {
          'sucesso': true,
          'dados': dados,
        };
      }

      // Se o login falhar, limpa qualquer token antigo
      sair();

      // Caso o backend retorne erro
      // Usa 'mensagem' se existir, senão usa 'message', que é comum nos erros do NestJS
      return {
        'sucesso': false,
        'mensagem': dados['mensagem'] ?? dados['message'] ?? 'Erro ao fazer login',
      };
    } catch (erro) { // Captura erro de conexão, backend desligado ou resposta inesperada

      // Se ocorrer erro inesperado, limpa qualquer token antigo
      sair();

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