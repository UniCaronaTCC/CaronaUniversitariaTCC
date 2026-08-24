import { BadRequestException } from '@nestjs/common';
import * as bcrypt from 'bcrypt';

import { UsersService } from '../users/users.service';
import { EmailService } from './email.service';
import { EmailVerificacaoService } from './email-verificacao.service';

describe('EmailVerificacaoService', () => {
  let service: EmailVerificacaoService;
  let usersService: {
    buscarPorEmailComVerificacao: jest.Mock;
    salvarUsuario: jest.Mock;
  };
  let emailService: {
    enviarCodigoVerificacao: jest.Mock;
  };

  beforeEach(() => {
    usersService = {
      buscarPorEmailComVerificacao: jest.fn(),
      salvarUsuario: jest.fn(),
    };
    emailService = {
      enviarCodigoVerificacao: jest.fn(),
    };

    service = new EmailVerificacaoService(
      usersService as unknown as UsersService,
      emailService as unknown as EmailService,
    );
  });

  it('gera e envia um código de seis números', async () => {
    const usuario = {
      nome: 'João',
      email: 'joao@email.com',
      emailVerificado: false,
      codigoVerificacaoEmail: null,
      codigoVerificacaoEmailExpiraEm: null,
      codigoVerificacaoEmailEnviadoEm: null,
    };
    usersService.buscarPorEmailComVerificacao.mockResolvedValue(usuario);

    await service.enviarCodigo(' JOAO@EMAIL.COM ');

    const codigoEnviado = emailService.enviarCodigoVerificacao.mock.calls[0][2];

    expect(codigoEnviado).toMatch(/^\d{6}$/);
    expect(
      await bcrypt.compare(codigoEnviado, usuario.codigoVerificacaoEmail!),
    ).toBe(true);
    expect(usersService.salvarUsuario).toHaveBeenCalledWith(usuario);
    expect(emailService.enviarCodigoVerificacao).toHaveBeenCalledWith(
      usuario.email,
      usuario.nome,
      codigoEnviado,
    );
  });

  it('confirma o e-mail quando o código está correto', async () => {
    const usuario = {
      emailVerificado: false,
      codigoVerificacaoEmail: await bcrypt.hash('123456', 4),
      codigoVerificacaoEmailExpiraEm: new Date(Date.now() + 60000),
      codigoVerificacaoEmailEnviadoEm: new Date(),
    };
    usersService.buscarPorEmailComVerificacao.mockResolvedValue(usuario);

    await service.confirmarCodigo('joao@email.com', '123456');

    expect(usuario.emailVerificado).toBe(true);
    expect(usuario.codigoVerificacaoEmail).toBeNull();
    expect(usuario.codigoVerificacaoEmailExpiraEm).toBeNull();
    expect(usuario.codigoVerificacaoEmailEnviadoEm).toBeNull();
    expect(usersService.salvarUsuario).toHaveBeenCalledWith(usuario);
  });

  it('recusa um código incorreto', async () => {
    usersService.buscarPorEmailComVerificacao.mockResolvedValue({
      emailVerificado: false,
      codigoVerificacaoEmail: await bcrypt.hash('123456', 4),
      codigoVerificacaoEmailExpiraEm: new Date(Date.now() + 60000),
    });

    await expect(
      service.confirmarCodigo('joao@email.com', '654321'),
    ).rejects.toBeInstanceOf(BadRequestException);
    expect(usersService.salvarUsuario).not.toHaveBeenCalled();
  });

  it('recusa um código expirado', async () => {
    usersService.buscarPorEmailComVerificacao.mockResolvedValue({
      emailVerificado: false,
      codigoVerificacaoEmail: await bcrypt.hash('123456', 4),
      codigoVerificacaoEmailExpiraEm: new Date(Date.now() - 60000),
    });

    await expect(
      service.confirmarCodigo('joao@email.com', '123456'),
    ).rejects.toThrow('Código expirado. Solicite um novo código.');
    expect(usersService.salvarUsuario).not.toHaveBeenCalled();
  });
});
