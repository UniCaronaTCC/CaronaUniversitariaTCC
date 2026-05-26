import 'package:flutter/material.dart'; // Importa os componentes visuais do Flutter
import 'cadastro.dart'; // Importa a tela de cadastro para permitir a navegação
import '../services/auth_service.dart'; // Importa o service responsável por conversar com o backend
import '../widgets/componentes_padrao.dart'; // Importa os componentes visuais padronizados do app
import '../home/tela_inicial.dart'; // Importa a tela inicial para abrir depois do login
import '../config/app_colors.dart'; // Importa as cores principais do app
import '../widgets/auth_widgets.dart'; // Importa os componentes visuais de login/cadastro

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
    if (emailController.text.isEmpty) { // Verifica se o campo de e-mail está vazio
      ScaffoldMessenger.of(context).showSnackBar( // Mostra uma mensagem temporária na parte de baixo da tela
        const SnackBar(content: Text('Informe seu e-mail')), // Mostra aviso caso o e-mail não tenha sido preenchido
      );
      return; // Para a função aqui para não chamar o backend sem e-mail
    }

    if (senhaController.text.isEmpty) { // Verifica se o campo de senha está vazio
      ScaffoldMessenger.of(context).showSnackBar( // Mostra uma mensagem temporária na parte de baixo da tela
        const SnackBar(content: Text('Informe sua senha')), // Mostra aviso caso a senha não tenha sido preenchida
      );
      return; // Para a função aqui para não chamar o backend sem senha
    }

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

    if (resultado['sucesso'] == true) { // Verifica se o login deu certo
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(resultado['dados']['mensagem'])), // Mostra mensagem de sucesso
      );

      Navigator.pushReplacement( // Troca a tela de login pela tela inicial
        context,
        MaterialPageRoute(
          builder: (context) => TelaInicial(
            nomeUsuario: resultado['dados']['usuario']['nome'].toString(), // Envia o nome real do usuário para a tela inicial
          ), // Abre a tela principal do app
        ),
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
    return Scaffold( // Estrutura base da tela
      backgroundColor: Colors.white,

      body: SafeArea( // Evita que fique embaixo da barra do celular
        child: Align(
          alignment: Alignment.center,
          child: SingleChildScrollView( // Permite rolar se a tela for pequena
            padding: const EdgeInsets.all(24), // Espaçamento externo
            child: Container( // Card principal do login
              width: double.infinity, // Ocupa toda a largura disponível
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 36), // Espaçamento interno
              decoration: BoxDecoration(
                color: AppColors.primary, // Fundo roxo do card
                borderRadius: BorderRadius.circular(28), // Bordas arredondadas
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(35), // Cor da sombra
                    blurRadius: 18, // Suaviza a sombra
                    offset: const Offset(0, 8), // Move a sombra para baixo
                  ),
                ],
              ),

              child: Column( // Organiza os elementos em coluna
                mainAxisSize: MainAxisSize.min, // Usa só o espaço necessário
                children: [
                  const Text(
                    'LOGIN',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
                  ),

                  const SizedBox(height: 6),

                  const Text(
                    'Entre na sua conta',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 16,
                      letterSpacing: 1,
                    ),
                  ),

                  const SizedBox(height: 36),

                  AuthCampoTexto( // Campo de e-mail estilizado
                    hint: 'E-mail',
                    icone: Icons.email,
                    controller: emailController,
                    keyboardType: TextInputType.emailAddress,
                  ),

                  const SizedBox(height: 16),

                  AuthCampoTexto( // Campo de senha estilizado
                    hint: 'Senha',
                    icone: Icons.lock,
                    controller: senhaController,
                    obscureText: true,
                  ),

                  const SizedBox(height: 24),

                  AuthBotaoPrincipal( // Botão principal de login
                    texto: carregando ? 'ENTRANDO...' : 'ENTRAR',
                    onPressed: carregando ? null : fazerLogin,
                  ),

                  const SizedBox(height: 18),

                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const CadastroTela(),
                        ),
                      );
                    },
                    child: const Text(
                      'Não tem uma conta? Cadastre-se',
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
      ),
    );
  }
}