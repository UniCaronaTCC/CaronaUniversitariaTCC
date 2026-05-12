import { Injectable, UnauthorizedException } from '@nestjs/common'; // Importa recursos do NestJS
import { UsersService } from '../users/users.service'; // Importa o service de usuários para buscar dados no banco

@Injectable()
export class AuthService {
  constructor(
    private readonly usersService: UsersService, // Permite usar funções do UsersService dentro do AuthService
  ) {}

  async login(email: string, senha: string) { // Função responsável por validar o login do usuário
    const usuario = await this.usersService.buscarPorEmail(email); // Busca no banco um usuário com o e-mail informado

    if (!usuario) { // Verifica se nenhum usuário foi encontrado
      throw new UnauthorizedException('E-mail ou senha inválidos'); // Retorna erro de login
    }

    if (usuario.senha !== senha) { // Compara a senha digitada com a senha salva no banco
      throw new UnauthorizedException('E-mail ou senha inválidos'); // Retorna erro se a senha estiver incorreta
    }

    return {
      mensagem: 'Login realizado com sucesso',
      usuario: {
        id: usuario.idUsuario,
        nome: usuario.nome,
        email: usuario.email,
      },
    };
  }
}