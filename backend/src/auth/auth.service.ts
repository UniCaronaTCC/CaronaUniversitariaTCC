import { ConflictException, Injectable, UnauthorizedException } from '@nestjs/common';
// Importa recursos do NestJS

import { UsersService } from '../users/users.service';
// Importa o service de usuários para buscar dados no banco

@Injectable()
export class AuthService {

  constructor(
    private readonly usersService: UsersService,
    // Permite usar funções do UsersService dentro do AuthService
  ) {}

  // FUNCAO DE LOGIN
  async login(email: string, senha: string) {

    // busca usuario pelo email
    const usuario = await this.usersService.buscarPorEmail(email);

    // verifica se usuario existe
    if (!usuario) {

      throw new UnauthorizedException(
        'E-mail ou senha inválidos',
      );
    }

    // verifica se senha esta correta
    if (usuario.senha !== senha) {

      throw new UnauthorizedException(
        'E-mail ou senha inválidos',
      );
    }

    // retorna sucesso
    return {

      mensagem: 'Login realizado com sucesso',

      usuario: {
        id: usuario.idUsuario,
        nome: usuario.nome,
        email: usuario.email,
      },
    };
  }

  // FUNCAO DE CADASTRO
  async cadastro(
    nome: string,
    email: string,
    senha: string,
  ) {

    // verifica se ja existe usuario com esse email
    const usuarioExistente =
      await this.usersService.buscarPorEmail(email);

    // se existir retorna erro
    if (usuarioExistente) {

      throw new ConflictException(
        'E-mail já cadastrado',
      );
    }

    // cria usuario no banco
    const novoUsuario =
      await this.usersService.criarUsuario(
        nome,
        email,
        senha,
      );

    // retorna sucesso
    return {

      mensagem: 'Cadastro realizado com sucesso',

      usuario: {
        id: novoUsuario.idUsuario,
        nome: novoUsuario.nome,
        email: novoUsuario.email,
      },
    };
  }
}