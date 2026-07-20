import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../config/app_colors.dart';
import '../widgets/auth_widgets.dart';
import 'login.dart';
// importa o service responsavel por conversar com o backend

class CadastroTela extends StatefulWidget {
  // cria a tela de cadastro
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Informe seu nome')));

      return; // para a funcao aqui
    }

    // verifica se o email esta vazio
    if (emailController.text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Informe seu e-mail')));

      return;
    }

    // verifica se a senha esta vazia
    if (senhaController.text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Informe sua senha')));

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

    // Verifica se a tela ainda está aberta depois da resposta do backend
    if (!mounted) {
      return;
    }

    // Desativa o loading
    setState(() {
      carregando = false;
    });

    // Verifica se o cadastro foi realizado com sucesso
    if (resultado['sucesso'] == true) {
      // Mostra a mensagem de sucesso
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            resultado['dados']['mensagem'] ?? 'Cadastro realizado com sucesso',
          ),
        ),
      );

      // Substitui a tela de cadastro pela tela de login
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginTela()),
      );

      return; // Encerra a função para não mostrar mensagem de erro
    }

    // Mostra a mensagem recebida caso o cadastro falhe
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(resultado['mensagem'])));
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
    return Scaffold(
      // estrutura base da tela
      backgroundColor: AppColors
          .background, // define a cor de fundo usando a cor padrao do app

      body: SafeArea(
        // evita que fique embaixo da barra do celular
        child: Align(
          // controla o alinhamento do conteudo
          alignment: Alignment.center, // centraliza o card na tela

          child: SingleChildScrollView(
            // permite rolar se a tela for pequena
            padding: const EdgeInsets.all(24), // espacamento externo

            child: AuthCard(
              // card visual reutilizavel para login/cadastro
              children: [
                const Text(
                  'CADASTRO',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                  ),
                ),

                const SizedBox(height: 6),

                const Text(
                  'Crie sua conta',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 16,
                    letterSpacing: 1,
                  ),
                ),

                const SizedBox(height: 36),

                // campo de nome
                AuthCampoTexto(
                  hint: 'Nome',

                  icone: Icons.person,

                  // conecta o campo ao controller
                  controller: nomeController,
                ),

                const SizedBox(height: 16),
                // espacamento entre os campos

                // campo de email
                AuthCampoTexto(
                  hint: 'E-mail',

                  icone: Icons.email,

                  controller: emailController,

                  // abre teclado apropriado pra email
                  keyboardType: TextInputType.emailAddress,
                ),

                const SizedBox(height: 16),

                // campo de senha
                AuthCampoTexto(
                  hint: 'Senha',

                  icone: Icons.lock,

                  controller: senhaController,

                  // esconde o texto digitado
                  obscureText: true,
                ),

                const SizedBox(height: 24),

                // botao de cadastrar
                AuthBotaoPrincipal(
                  texto: carregando ? 'CADASTRANDO...' : 'CADASTRAR',

                  onPressed: carregando ? null : fazerCadastro,
                ),

                //para voltar pro login se ja tiver cadastro
                const SizedBox(height: 18),

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
                      color: Colors.white,
                      decoration: TextDecoration.underline,
                      decorationColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
