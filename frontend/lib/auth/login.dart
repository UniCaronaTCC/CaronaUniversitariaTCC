import 'package:flutter/material.dart'; // Importa os componentes visuais do Flutter

class LoginTela extends StatelessWidget { // Cria a tela 'LoginTela'
  const LoginTela({super.key});           // Construtor da tela LoginTela

  @override
  // Tudo que aparece visualmente no app fica aqui
  Widget build(BuildContext context) {
    return Scaffold( // 'Scaffold' é a estrutura base de tela no Flutter
      appBar: AppBar( // Cria a barra no topo da tela
        title: const Text('Login'),
      ),

      // conteúdo principal da tela fica no 'body'
      body: Padding(
        padding: const EdgeInsets.all(24), // padding é o espaço, 24px em todos lados
        child: Column( // O Column organiza os elementos um embaixo do outro
          mainAxisAlignment: MainAxisAlignment.center, // centraliza esses elementos na vertical da tela
          children: [ // O children é a lista de coisas que vão aparecer dentro da coluna
            const TextField( // Cria um campo para o usuário digitar
              decoration: InputDecoration(
                labelText: 'E-mail', // nome do campo
                enabledBorder: OutlineInputBorder( // cria aquela borda em volta do campo
                  borderSide: BorderSide(color: Color(0xFF8F16D9)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Color(0xFF8F16D9), width: 2),
                ),
              ),
            ),

            const SizedBox(height: 16), // Cria um espaço vertical de 16 pixels

            const TextField( // outro campo de texto
              obscureText: true, // esconde o que for digitado
              decoration: InputDecoration(
                labelText: 'Senha',
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Color(0xFF8F16D9)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Color(0xFF8F16D9), width: 2),
                ),
              ),
            ),

            const SizedBox(height: 24), // cria espaço maior antes do botão

            SizedBox( // controla o tamanho
              width: double.infinity, // significa que o botão vai ocupar toda largura disponível

              // cria o botão 'Entrar'
              child: ElevatedButton(
                onPressed: () {
                  print('Entrar clicado'); // isso só aparece no terminal
                },
                child: const Text('Entrar'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}