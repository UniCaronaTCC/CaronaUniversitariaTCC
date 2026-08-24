import { BadRequestException } from '@nestjs/common';
import * as bcrypt from 'bcrypt';

import { UsersService } from '../users/users.service';
import { EmailService } from './email.service';
import { EmailVerificacaoService } from './email-verificacao.service';

describe('EmailVerificacaoService', () => {
  let service: EmailVerificacaoService;
  let usersService: {
    buscarPorEmailComVerificacao: jest.Mock;
    buscarPorEmailComRedefinicao: jest.Mock;
    salvarUsuario: jest.Mock;
  };
  let emailService: {
    enviarCodigoVerificacao: jest.Mock;
    enviarCodigoRedefinicaoSenha: jest.Mock;
  };

  beforeEach(() => {
    usersService = {
      buscarPorEmailComVerificacao: jest.fn(),
      buscarPorEmailComRedefinicao: jest.fn(),
      salvarUsuario: jest.fn(),
    };
    emailService = {
      enviarCodigoVerificacao: jest.fn(),
      enviarCodigoRedefinicaoSenha: jest.fn(),
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

  it('envia código para redefinir a senha', async () => {
    const usuario = {
      nome: 'João',
      email: 'joao@email.com',
      codigoRedefinicaoSenha: null,
      codigoRedefinicaoSenhaExpiraEm: null,
      codigoRedefinicaoSenhaEnviadoEm: null,
    };
    usersService.buscarPorEmailComRedefinicao.mockResolvedValue(usuario);

    await service.enviarCodigoRedefinicaoSenha('joao@email.com');

    const codigoEnviado =
      emailService.enviarCodigoRedefinicaoSenha.mock.calls[0][2];

    expect(codigoEnviado).toMatch(/^\d{6}$/);
    expect(
      await bcrypt.compare(codigoEnviado, usuario.codigoRedefinicaoSenha!),
    ).toBe(true);
    expect(emailService.enviarCodigoRedefinicaoSenha).toHaveBeenCalledWith(
      usuario.email,
      usuario.nome,
      codigoEnviado,
    );
  });

  it('não revela quando o e-mail não está cadastrado', async () => {
    usersService.buscarPorEmailComRedefinicao.mockResolvedValue(null);

    await expect(
      service.enviarCodigoRedefinicaoSenha('outro@email.com'),
    ).resolves.toBeUndefined();

    expect(usersService.salvarUsuario).not.toHaveBeenCalled();
    expect(emailService.enviarCodigoRedefinicaoSenha).not.toHaveBeenCalled();
  });

  it('não revela que um código já foi enviado recentemente', async () => {
    usersService.buscarPorEmailComRedefinicao.mockResolvedValue({
      codigoRedefinicaoSenhaEnviadoEm: new Date(),
    });

    await expect(
      service.enviarCodigoRedefinicaoSenha('joao@email.com'),
    ).resolves.toBeUndefined();

    expect(usersService.salvarUsuario).not.toHaveBeenCalled();
    expect(emailService.enviarCodigoRedefinicaoSenha).not.toHaveBeenCalled();
  });

  it('limpa o código quando o serviço de e-mail falha', async () => {
    const usuario = {
      nome: 'João',
      email: 'joao@email.com',
      codigoRedefinicaoSenha: null,
      codigoRedefinicaoSenhaExpiraEm: null,
      codigoRedefinicaoSenhaEnviadoEm: null,
    };
    usersService.buscarPorEmailComRedefinicao.mockResolvedValue(usuario);
    emailService.enviarCodigoRedefinicaoSenha.mockRejectedValue(
      new Error('Falha no envio'),
    );

    await expect(
      service.enviarCodigoRedefinicaoSenha('joao@email.com'),
    ).resolves.toBeUndefined();

    expect(usuario.codigoRedefinicaoSenha).toBeNull();
    expect(usuario.codigoRedefinicaoSenhaExpiraEm).toBeNull();
    expect(usuario.codigoRedefinicaoSenhaEnviadoEm).toBeNull();
    expect(usersService.salvarUsuario).toHaveBeenCalledTimes(2);
  });

  it('redefine a senha com código válido', async () => {
    const senhaAntiga = await bcrypt.hash('antiga123', 4);
    const usuario = {
      senha: senhaAntiga,
      codigoRedefinicaoSenha: await bcrypt.hash('123456', 4),
      codigoRedefinicaoSenhaExpiraEm: new Date(Date.now() + 60000),
      codigoRedefinicaoSenhaEnviadoEm: new Date(),
    };
    usersService.buscarPorEmailComRedefinicao.mockResolvedValue(usuario);

    await service.redefinirSenha('joao@email.com', '123456', 'novaSenha123');

    expect(await bcrypt.compare('novaSenha123', usuario.senha)).toBe(true);
    expect(usuario.codigoRedefinicaoSenha).toBeNull();
    expect(usuario.codigoRedefinicaoSenhaExpiraEm).toBeNull();
    expect(usuario.codigoRedefinicaoSenhaEnviadoEm).toBeNull();
    expect(usersService.salvarUsuario).toHaveBeenCalledWith(usuario);
  });

  it('recusa redefinição com código expirado', async () => {
    usersService.buscarPorEmailComRedefinicao.mockResolvedValue({
      senha: await bcrypt.hash('antiga123', 4),
      codigoRedefinicaoSenha: await bcrypt.hash('123456', 4),
      codigoRedefinicaoSenhaExpiraEm: new Date(Date.now() - 60000),
      codigoRedefinicaoSenhaEnviadoEm: new Date(),
    });

    await expect(
      service.redefinirSenha('joao@email.com', '123456', 'novaSenha123'),
    ).rejects.toThrow('Código expirado. Solicite um novo código.');
    expect(usersService.salvarUsuario).not.toHaveBeenCalled();
  });

  it('recusa uma nova senha fraca', async () => {
    await expect(
      service.redefinirSenha('joao@email.com', '123456', '12345678'),
    ).rejects.toBeInstanceOf(BadRequestException);
    expect(usersService.buscarPorEmailComRedefinicao).not.toHaveBeenCalled();
  });
});
