import 'package:flutter/material.dart'; // Importa os componentes visuais do Flutter
import '../config/app_colors.dart';
import '../services/auth_service.dart'; // Importa o service responsável por conversar com o backend

class LoginTela extends StatefulWidget { // Cria a tela 'LoginTela'
  const LoginTela({super.key});           // Construtor da tela LoginTela

  @override
  State<LoginTela> createState() => _LoginTelaState(); // Cria o estado da tela, permitindo guardar dados digitados e atualizar a interface
}

class _LoginTelaState extends State<LoginTela> { // Classe que controla o estado da tela de login
  final TextEditingController emailController = TextEditingController(); // Controla o texto digitado no campo de e-mail
  final TextEditingController senhaController = TextEditingController(); // Controla o texto digitado no campo de senha

  bool carregando = false; // Controla se o botão está em estado de carregamento ou não

  Future<void> fazerLogin() async { // Função responsável por tentar fazer login usando o backend
    setState(() { // Atualiza a tela
      carregando = true; // Ativa o carregamento do botão
    });

    final resultado = await AuthService.fazerLogin( // Chama o service que envia e-mail e senha para o backend
      emailController.text, // Pega o e-mail digitado pelo usuário
      senhaController.text, // Pega a senha digitada pelo usuário
    );

    setState(() { // Atualiza a tela novamente
      carregando = false; // Desativa o carregamento do botão
    });

    if (resultado['sucesso'] == true) { // Verifica se o backend respondeu que o login deu certo
      ScaffoldMessenger.of(context).showSnackBar( // Mostra uma mensagem temporária na parte de baixo da tela
        SnackBar(content: Text(resultado['dados']['mensagem'])), // Mostra a mensagem de sucesso enviada pelo backend
      );
    } else { // Caso o login tenha falhado
      ScaffoldMessenger.of(context).showSnackBar( // Mostra uma mensagem temporária na parte de baixo da tela
        SnackBar(content: Text(resultado['mensagem'])), // Mostra a mensagem de erro enviada pelo backend
      );
    }
  }

  @override
  void dispose() { // Função chamada quando a tela é fechada
    emailController.dispose(); // Libera o controller do campo de e-mail da memória
    senhaController.dispose(); // Libera o controller do campo de senha da memória
    super.dispose(); // Mantém o comportamento padrão do Flutter ao fechar a tela
  }

  @override
  // Tudo que aparece visualmente no app fica aqui
  Widget build(BuildContext context) {
    return Scaffold( // 'Scaffold' é a estrutura base de tela do Flutter
      appBar: AppBar( // Cria a barra no topo da tela
        title: const Text('Login'),
      ),

      // conteúdo principal da tela fica no 'body'
      body: Padding(
        padding: const EdgeInsets.all(24), // padding é o espaço, 24px em todos lados
        child: Column( // O Column organiza os elementos um embaixo do outro
          mainAxisAlignment: MainAxisAlignment.center, // centraliza esses elementos na vertical da tela
          children: [ // O children é a lista de coisas que vão aparecer dentro da coluna
            TextField( // Cria um campo para o usuário digitar
              controller: emailController, // Liga esse campo ao controller que guarda o e-mail digitado
              decoration: const InputDecoration(
                labelText: 'E-mail', // nome do campo
                enabledBorder: OutlineInputBorder( // cria aquela borda em volta do campo
                  borderSide: BorderSide(color: AppColors.primary),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: AppColors.primary, width: 3), // espessura da borda do campo
                ),
              ),
            ),

            const SizedBox(height: 16), // Cria um espaço vertical de 16 pixels

            TextField( // outro campo de texto
              controller: senhaController, // Liga esse campo ao controller que guarda a senha digitada
              obscureText: true, // esconde o que for digitado
              decoration: const InputDecoration(
                labelText: 'Senha',
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: AppColors.primary),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: AppColors.primary, width: 3),
                ),
              ),
            ),

            const SizedBox(height: 24), // cria espaço maior antes do botão

            SizedBox( // controla o tamanho
              width: double.infinity, // significa que o botão vai ocupar toda largura disponível

              // cria o botão 'Entrar'
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primaryContainer, // cor de fundo do botão, puxada do tema global
                  foregroundColor: Theme.of(context).colorScheme.primary, // cor do texto do botão, puxada do tema global
                ),
                onPressed: carregando ? null : fazerLogin, // Se estiver carregando, desativa o botão; se não, chama a função de login
                child: Text(carregando ? 'Entrando...' : 'Entrar'), // Muda o texto do botão enquanto o login está sendo feito
              ),
            ),

            const SizedBox(height: 16), // cria um espaço entre o botão entrar e o botão cadastre-se

            // cria o botão 'cadastre-se'
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.primary, // cor do texto, puxada do tema global
              ),
              onPressed: () {
                print('Ir para cadastro'); // isso só aparece no terminal também
              },
              child: const Text(
                'Não tem uma conta? Cadastre-se',
                style: TextStyle(
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}