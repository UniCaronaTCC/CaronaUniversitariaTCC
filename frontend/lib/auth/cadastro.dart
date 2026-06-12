import 'package:flutter/material.dart';
import '../widgets/componentes_padrao.dart';
import '../services/auth_service.dart';
import 'login.dart';
// importa o service responsavel por conversar com o backend

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
  Future<void> fazerCadastro() async {

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

    // ativa o loading da tela
    setState(() {
      carregando = true;
    });

    // chama o backend enviando os dados do cadastro
    final resultado = await AuthService.fazerCadastro(

      // pega o nome digitado
      nomeController.text,

      // pega o email digitado
      emailController.text,

      // pega a senha digitada
      senhaController.text,
    );

    // desativa o loading
    setState(() {
      carregando = false;
    });

    // mostra a resposta do backend na tela
    ScaffoldMessenger.of(context).showSnackBar(

      SnackBar(

        content: Text(

          // verifica se deu sucesso ou erro
          resultado['sucesso'] == true

          // mensagem de sucesso
              ? resultado['dados']['mensagem']
              ?? 'Cadastro realizado com sucesso'

          // mensagem de erro
              : resultado['mensagem'],
        ),
      ),
    );
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
              texto: carregando
                  ? 'Cadastrando...'
                  : 'Cadastrar',

              onPressed: carregando
                  ? null
                  : fazerCadastro,
            ),

            //para voltar pro login se ja tiver cadastro
            const SizedBox(height: 16),

            TextButton(
              onPressed: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const LoginTela(),
                  ),
                );
              },
              child: const Text(
                'Já tem uma conta? Entrar',
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