import { BadRequestException, UnauthorizedException } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import * as bcrypt from 'bcrypt';
import { EmailVerificacaoService } from '../email/email-verificacao.service';
import { UsersService } from '../users/users.service';
import { AuthService } from './auth.service';

describe('AuthService', () => {
  let service: AuthService;
  let usersService: {
    buscarPorEmail: jest.Mock;
    buscarPorEmailComSenha: jest.Mock;
    criarUsuario: jest.Mock;
  };
  let jwtService: { signAsync: jest.Mock };
  let emailVerificacaoService: {
    enviarCodigo: jest.Mock;
    confirmarCodigo: jest.Mock;
  };

  beforeEach(() => {
    usersService = {
      buscarPorEmail: jest.fn(),
      buscarPorEmailComSenha: jest.fn(),
      criarUsuario: jest.fn(),
    };
    jwtService = { signAsync: jest.fn() };
    emailVerificacaoService = {
      enviarCodigo: jest.fn(),
      confirmarCodigo: jest.fn(),
    };

    service = new AuthService(
      usersService as unknown as UsersService,
      jwtService as unknown as JwtService,
      emailVerificacaoService as unknown as EmailVerificacaoService,
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
      instituicao: 'UniSalesiano',
      campus: 'Araçatuba',
      fotoPerfil: 'https://exemplo.com/foto',
      tipoPerfil: 'AMBOS',
      tipoPerfilSolicitado: null,
      statusVerificacao: 'APROVADO',
      emailVerificado: true,
    });
    jwtService.signAsync.mockResolvedValue('token-teste');

    const resultado = await service.login(' JOAO@EMAIL.COM ', '123456');

    expect(usersService.buscarPorEmailComSenha).toHaveBeenCalledWith(
      'joao@email.com',
    );
    expect(resultado.token).toBe('token-teste');
    expect(resultado.usuario).toEqual({
      id: 1,
      nome: 'João',
      email: 'joao@email.com',
      instituicao: 'UniSalesiano',
      campus: 'Araçatuba',
      fotoPerfil: 'https://exemplo.com/foto',
      tipoPerfil: 'AMBOS',
      tipoPerfilSolicitado: null,
      statusVerificacao: 'APROVADO',
      emailVerificado: true,
    });
    expect(resultado.usuario).not.toHaveProperty('senha');
  });

  it('recusa login quando o e-mail ainda não foi confirmado', async () => {
    const senhaHash = await bcrypt.hash('123456', 4);

    usersService.buscarPorEmailComSenha.mockResolvedValue({
      idUsuario: 1,
      email: 'joao@email.com',
      senha: senhaHash,
      emailVerificado: false,
    });

    await expect(
      service.login('joao@email.com', '123456'),
    ).rejects.toBeInstanceOf(UnauthorizedException);
  });

  it('recusa cadastro com senha fraca', async () => {
    await expect(
      service.cadastro('João', 'joao@email.com', '12345678'),
    ).rejects.toBeInstanceOf(BadRequestException);

    expect(usersService.buscarPorEmail).not.toHaveBeenCalled();
    expect(usersService.criarUsuario).not.toHaveBeenCalled();
  });

  it('recusa cadastro com e-mail inválido', async () => {
    await expect(
      service.cadastro('João', 'email-invalido', 'carona123'),
    ).rejects.toBeInstanceOf(BadRequestException);

    expect(usersService.buscarPorEmail).not.toHaveBeenCalled();
    expect(usersService.criarUsuario).not.toHaveBeenCalled();
  });
});
