import { ExecutionContext, UnauthorizedException } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';

import { UsersService } from '../users/users.service';
import { JwtAuthGuard } from './jwt-auth.guard';
import { SupabaseAuthService } from './supabase-auth.service';

describe('JwtAuthGuard', () => {
  const jwtService = {
    verifyAsync: jest.fn(),
  };
  const supabaseAuthService = {
    buscarUsuario: jest.fn(),
  };
  const usersService = {
    buscarPorAuthId: jest.fn(),
  };

  let guard: JwtAuthGuard;

  beforeEach(() => {
    jest.clearAllMocks();

    guard = new JwtAuthGuard(
      jwtService as unknown as JwtService,
      supabaseAuthService as unknown as SupabaseAuthService,
      usersService as unknown as UsersService,
    );
  });

  function criarContexto(token: string) {
    const request = {
      headers: {
        authorization: `Bearer ${token}`,
      },
      usuario: undefined,
    };
    const context = {
      switchToHttp: () => ({
        getRequest: () => request,
      }),
    } as unknown as ExecutionContext;

    return { context, request };
  }

  it('continua aceitando o JWT antigo', async () => {
    jwtService.verifyAsync.mockResolvedValue({
      sub: 1,
      email: 'joao@email.com',
      nome: 'João',
    });
    const { context, request } = criarContexto('token-antigo');

    await expect(guard.canActivate(context)).resolves.toBe(true);

    expect(request.usuario).toEqual({
      sub: 1,
      email: 'joao@email.com',
      nome: 'João',
    });
    expect(supabaseAuthService.buscarUsuario).not.toHaveBeenCalled();
  });

  it('aceita o token do Supabase e encontra o id local', async () => {
    jwtService.verifyAsync.mockRejectedValue(new Error('token diferente'));
    supabaseAuthService.buscarUsuario.mockResolvedValue({
      authId: 'uuid-do-supabase',
      email: 'joao@email.com',
    });
    usersService.buscarPorAuthId.mockResolvedValue({
      idUsuario: 7,
      email: 'joao@email.com',
      nome: 'João',
    });
    const { context, request } = criarContexto('token-supabase');

    await expect(guard.canActivate(context)).resolves.toBe(true);

    expect(usersService.buscarPorAuthId).toHaveBeenCalledWith(
      'uuid-do-supabase',
    );
    expect(request.usuario).toEqual({
      sub: 7,
      email: 'joao@email.com',
      nome: 'João',
    });
  });

  it('recusa um token que não é válido em nenhum dos dois serviços', async () => {
    jwtService.verifyAsync.mockRejectedValue(new Error('token inválido'));
    supabaseAuthService.buscarUsuario.mockResolvedValue(null);
    const { context } = criarContexto('token-invalido');

    await expect(guard.canActivate(context)).rejects.toBeInstanceOf(
      UnauthorizedException,
    );
  });
});
