import 'package:flutter/material.dart';
import '../config/app_colors.dart';

class CadastroTela extends StatelessWidget { //cria a tela de cadastro
  const CadastroTela({super.key}); //obrigatorio para construir a tela

  @override //substitui/sobrescreve o metodo da classe pai
  Widget build(BuildContext context) { // monta a tela toda, tudo visual fica ai
    return Scaffold( //base da tela, quase smp tem que ter organiza o resto
      appBar: AppBar(  //cria a barra do topo da tela
        title: const Text('Cadastro'), // texto que aparece no appBar
      ),

      body: Padding( //BODY: o que vai ter na tela principal // PADDING cria o espaçamento interno
        padding: const EdgeInsets.all(24), // vai colocar 24px de espaco em todos os lados
        child: Column( //pra organizar os intens em coluna (um embaixo do outro)
          mainAxisAlignment: MainAxisAlignment.center, // para centralizar os itens verticalmente, se nao ia ficar tudo no topo
          children: [ // O children é a lista de coisas que vão aparecer dentro da coluna
            const TextField( // Cria um campo para o usuário digitar
              decoration: InputDecoration( //para costumizar o campo
                labelText: 'Nome', // o texto que vai ficar no campo
                enabledBorder: OutlineInputBorder( //cria a borda em volta do campo
                  borderSide: BorderSide(color: AppColors.primary), //para definir a cor da borda, aqui esta usando a predefinida do app
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: AppColors.primary, width: 2),
                ),
              ),
            ),

            const SizedBox(height: 16),

            const TextField(
              decoration: InputDecoration(
                labelText: 'E-mail',
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: AppColors.primary),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: AppColors.primary, width: 2),
                ),
              ),
            ),

            const SizedBox(height: 16),

            const TextField(
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'Senha',
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: AppColors.primary),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: AppColors.primary, width: 2),
                ),
              ),
            ),

            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  print('Cadastro clicado');
                },
                child: const Text('Cadastrar'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}