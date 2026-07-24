import { BadRequestException, UnauthorizedException } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import * as bcrypt from 'bcrypt';
import { UsersService } from '../users/users.service';
import { AuthService } from './auth.service';

describe('AuthService', () => {
  let service: AuthService;
  let usersService: {
    buscarPorEmail: jest.Mock;
    buscarPorEmailComSenha: jest.Mock;
    criarUsuario: jest.Mock;
  };
  let jwtService: {
    signAsync: jest.Mock;
  };

  beforeEach(() => {
    usersService = {
      buscarPorEmail: jest.fn(),
      buscarPorEmailComSenha: jest.fn(),
      criarUsuario: jest.fn(),
    };
    jwtService = {
      signAsync: jest.fn(),
    };

    service = new AuthService(
      usersService as unknown as UsersService,
      jwtService as unknown as JwtService,
    );
  });

  it('recusa login quando o usuário não existe', async () => {
    usersService.buscarPorEmailComSenha.mockResolvedValue(null);

    await expect(
      service.login('inexistente@email.com', 'senha'),
    ).rejects.toBeInstanceOf(UnauthorizedException);
  });

  it('gera token sem retornar a senha no login', async () => {
    const senhaHash = await bcrypt.hash('123456', 4);

    usersService.buscarPorEmailComSenha.mockResolvedValue({
      idUsuario: 1,
      nome: 'João',
      email: 'joao@email.com',
      senha: senhaHash,
    });
    jwtService.signAsync.mockResolvedValue('token-teste');

    const resultado = await service.login('joao@email.com', '123456');

    expect(resultado.token).toBe('token-teste');
    expect(resultado.usuario).toEqual({
      id: 1,
      nome: 'João',
      email: 'joao@email.com',
    });
    expect(resultado.usuario).not.toHaveProperty('senha');
  });

  it('recusa cadastro com senha fraca', async () => {
    await expect(
      service.cadastro('João', 'joao@email.com', '12345678'),
    ).rejects.toBeInstanceOf(BadRequestException);

    expect(usersService.buscarPorEmail).not.toHaveBeenCalled();
    expect(usersService.criarUsuario).not.toHaveBeenCalled();
  });
});
