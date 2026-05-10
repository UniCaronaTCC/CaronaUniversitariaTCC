import 'package:flutter/material.dart';
import '../widgets/componentes_padrao.dart';

class CadastroTela extends StatefulWidget { // cria a tela de cadastro
  const CadastroTela({super.key}); // construtor padrao da tela

  @override
  State<CadastroTela> createState() => _CadastroTelaState();
// cria o estado da tela, necessario pq vamos guardar infos digitadas
}

class _CadastroTelaState extends State<CadastroTela> {

  // controllers servem pra controlar e pegar o texto digitado nos campos
  final TextEditingController nomeController = TextEditingController();

  final TextEditingController emailController = TextEditingController();

  final TextEditingController senhaController = TextEditingController();

  // bool pra saber se ta carregando ou nao
  bool carregando = false;

  // funcao que vai rodar quando clicar no botao cadastrar
  void fazerCadastro() {

    // verifica se o campo nome esta vazio
    if (nomeController.text.isEmpty) {

      // mostra uma mensagenzinha na parte de baixo da tela
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Informe seu nome'),
        ),
      );

      return; // para a funcao aqui
    }

    // verifica se o email esta vazio
    if (emailController.text.isEmpty) {

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Informe seu e-mail'),
        ),
      );

      return;
    }

    // verifica se a senha esta vazia
    if (senhaController.text.isEmpty) {

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Informe sua senha'),
        ),
      );

      return;
    }

    // printa os dados no terminal so pra teste
    print(nomeController.text);

    print(emailController.text);

    print(senhaController.text);
  }

  @override

  // funcao chamada quando a tela e fechada
  void dispose() {

    // libera os controllers da memoria
    nomeController.dispose();

    emailController.dispose();

    senhaController.dispose();

    super.dispose();
  }

  @override

  // tudo que aparece visualmente fica aqui
  Widget build(BuildContext context) {

    return Scaffold( // estrutura base da tela

      appBar: AppBar( // barra de cima
        title: const Text('Cadastro'),
      ),

      body: Padding( // espacamento interno da tela

        padding: const EdgeInsets.all(24),

        child: Column( // organiza tudo em coluna

          mainAxisAlignment: MainAxisAlignment.center,
          // centraliza os itens verticalmente

          children: [

            // campo de nome
            CampoTextoPadrao(

              label: 'Nome',

              // conecta o campo ao controller
              controller: nomeController,
            ),

            const SizedBox(height: 16),
            // espacamento entre os campos

            // campo de email
            CampoTextoPadrao(

              label: 'E-mail',

              controller: emailController,

              // abre teclado apropriado pra email
              keyboardType: TextInputType.emailAddress,
            ),

            const SizedBox(height: 16),

            // campo de senha
            CampoTextoPadrao(

              label: 'Senha',

              controller: senhaController,

              // esconde o texto digitado
              obscureText: true,
            ),

            const SizedBox(height: 24),

            // botao de cadastrar
            BotaoPadrao(

              // se tiver carregando muda o texto do botao
              texto: carregando
                  ? 'Cadastrando...'
                  : 'Cadastrar',

              // se tiver carregando desativa o botao
              onPressed: carregando
                  ? null
                  : fazerCadastro,
            ),
          ],
        ),
      ),
    );
  }
}