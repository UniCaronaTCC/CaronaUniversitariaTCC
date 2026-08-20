import { NotFoundException } from '@nestjs/common';
import { Request } from 'express';

import { FotoPerfilService } from './foto-perfil.service';
import { UsersController } from './users.controller';
import { UsersService } from './users.service';

describe('UsersController', () => {
  let controller: UsersController;
  let usersService: {
    buscarPorId: jest.Mock;
    atualizarPerfil: jest.Mock;
    atualizarFotoPerfil: jest.Mock;
  };
  let fotoPerfilService: { enviar: jest.Mock };

  beforeEach(() => {
    usersService = {
      buscarPorId: jest.fn(),
      atualizarPerfil: jest.fn(),
      atualizarFotoPerfil: jest.fn(),
    };
    fotoPerfilService = { enviar: jest.fn() };

    controller = new UsersController(
      usersService as unknown as UsersService,
      fotoPerfilService as unknown as FotoPerfilService,
    );
  });

  it('retorna os dados públicos do perfil', async () => {
    usersService.buscarPorId.mockResolvedValue({
      idUsuario: 1,
      nome: 'João',
      email: 'joao@email.com',
      idInstituicao: 1,
      instituicao: 'UniSalesiano',
      campus: 'Araçatuba',
      fotoPerfil: null,
      tipoPerfil: 'AMBOS',
      tipoPerfilSolicitado: null,
      statusVerificacao: 'APROVADO',
      senha: 'hash-que-nao-deve-sair',
    });

    const request = {
      usuario: { sub: 1, nome: 'João', email: 'joao@email.com' },
    } as unknown as Request & {
      usuario: { sub: number; nome: string; email: string };
    };

    const resultado = await controller.buscarPerfil(request);

    expect(resultado.dados).toEqual({
      id: 1,
      nome: 'João',
      email: 'joao@email.com',
      idInstituicao: 1,
      instituicao: 'UniSalesiano',
      campus: 'Araçatuba',
      fotoPerfil: null,
      tipoPerfil: 'AMBOS',
      tipoPerfilSolicitado: null,
      statusVerificacao: 'APROVADO',
    });
    expect(resultado.dados).not.toHaveProperty('senha');
  });

  it('informa quando o usuário não existe', async () => {
    usersService.buscarPorId.mockResolvedValue(null);

    const request = {
      usuario: { sub: 99, nome: 'Teste', email: 'teste@email.com' },
    } as unknown as Request & {
      usuario: { sub: number; nome: string; email: string };
    };

    await expect(controller.buscarPerfil(request)).rejects.toBeInstanceOf(
      NotFoundException,
    );
  });

  it('atualiza os dados do perfil', async () => {
    usersService.atualizarPerfil.mockResolvedValue({
      idUsuario: 1,
      nome: 'João',
      email: 'joao@email.com',
      idInstituicao: 1,
      instituicao: 'UniSalesiano',
      campus: 'Araçatuba',
      fotoPerfil: null,
      tipoPerfil: 'PASSAGEIRO',
      tipoPerfilSolicitado: 'MOTORISTA',
      statusVerificacao: 'NAO_ENVIADO',
    });

    const request = {
      usuario: { sub: 1, nome: 'João', email: 'joao@email.com' },
    } as unknown as Request & {
      usuario: { sub: number; nome: string; email: string };
    };

    const resultado = await controller.atualizarPerfil(
      {
        idInstituicao: 1,
        campus: 'Araçatuba',
        tipoPerfil: 'MOTORISTA',
        statusVerificacao: 'APROVADO',
      },
      request,
    );

    expect(resultado.mensagem).toBe('Perfil atualizado com sucesso');
    expect(resultado.dados.instituicao).toBe('UniSalesiano');
    expect(resultado.dados.tipoPerfil).toBe('PASSAGEIRO');
    expect(resultado.dados.statusVerificacao).toBe('NAO_ENVIADO');
    expect(usersService.atualizarPerfil).toHaveBeenCalledWith(
      1,
      1,
      'Araçatuba',
    );
  });

  it('recusa arquivo que não é uma imagem permitida', async () => {
    const request = {
      usuario: { sub: 1, nome: 'João', email: 'joao@email.com' },
    } as unknown as Request & {
      usuario: { sub: number; nome: string; email: string };
    };

    await expect(
      controller.atualizarFotoPerfil(
        { buffer: Buffer.from('arquivo-invalido') },
        request,
      ),
    ).rejects.toThrow('Envie uma imagem JPG, PNG ou WebP');

    expect(fotoPerfilService.enviar).not.toHaveBeenCalled();
  });
});
