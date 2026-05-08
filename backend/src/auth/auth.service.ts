import { Injectable, UnauthorizedException } from '@nestjs/common';

@Injectable()
export class AuthService {
  login(email: string, senha: string) {
    if (email === 'teste@email.com' && senha === '123456') {
      return {
        mensagem: 'Login realizado com sucesso',
        usuario: {
          id: 1,
          nome: 'Usuário Teste',
          email: email,
        },
      };
    }

    throw new UnauthorizedException('E-mail ou senha inválidos');
  }
}