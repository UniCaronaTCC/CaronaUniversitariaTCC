import {
  BadRequestException,
  ConflictException,
  NotFoundException,
} from '@nestjs/common';
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
    buscarVeiculo: jest.Mock;
    salvarVeiculo: jest.Mock;
  };
  let fotoPerfilService: { enviar: jest.Mock; remover: jest.Mock };

  beforeEach(() => {
    usersService = {
      buscarPorId: jest.fn(),
      atualizarPerfil: jest.fn(),
      atualizarFotoPerfil: jest.fn(),
      buscarVeiculo: jest.fn().mockResolvedValue(null),
      salvarVeiculo: jest.fn(),
    };
    fotoPerfilService = {
      enviar: jest.fn(),
      remover: jest.fn().mockResolvedValue(undefined),
    };

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
      statusVerificacaoCnh: 'NAO_ENVIADA',
      cnhCategoria: null,
      cnhValidade: null,
      cpf: '52998224725',
      cnhRegistroFinal: '8901',
      cnhNome: 'JOAO SILVA',
      cnhRegistro: '12345678901',
      senha: 'hash-que-nao-deve-sair',
    });
    usersService.buscarVeiculo.mockResolvedValue({
      idVeiculo: 1,
      modelo: 'Onix',
      cor: 'Branco',
      placa: 'ABC1D23',
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
      statusVerificacaoCnh: 'NAO_ENVIADA',
      cnhCategoria: null,
      cnhValidade: null,
      veiculo: {
        id: 1,
        modelo: 'Onix',
        cor: 'Branco',
        placa: 'ABC1D23',
      },
    });
    expect(resultado.dados).not.toHaveProperty('senha');
    expect(resultado.dados).not.toHaveProperty('cpf');
    expect(resultado.dados).not.toHaveProperty('cnhRegistroFinal');
    expect(resultado.dados).not.toHaveProperty('cnhNome');
    expect(resultado.dados).not.toHaveProperty('cnhRegistro');
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

  it('retorna a nova foto preservando veiculo e status da CNH', async () => {
    const usuario = {
      idUsuario: 1,
      nome: 'Teste',
      statusVerificacaoCnh: 'APROVADA',
      cnhCategoria: 'AB',
      cnhValidade: '2099-05-01',
      cpf: '52998224725',
    };
    const url = 'https://exemplo.com/foto?v=2';
    usersService.buscarPorId.mockResolvedValue(usuario);
    fotoPerfilService.enviar.mockResolvedValue(url);
    usersService.atualizarFotoPerfil.mockResolvedValue({
      ...usuario,
      fotoPerfil: url,
    });
    usersService.buscarVeiculo.mockResolvedValue({
      idVeiculo: 7,
      modelo: 'Onix',
      cor: 'Branco',
      placa: 'ABC1D23',
    });
    const request = { usuario: { sub: 1 } } as unknown as Parameters<
      UsersController['atualizarFotoPerfil']
    >[1];
    const foto = { buffer: Buffer.from([0xff, 0xd8, 0xff, 0x00]) };

    const resultado = await controller.atualizarFotoPerfil(foto, request);

    expect(fotoPerfilService.enviar).toHaveBeenCalledWith(
      1,
      foto.buffer,
      'image/jpeg',
    );
    expect(usersService.atualizarFotoPerfil).toHaveBeenCalledWith(usuario, url);
    expect(resultado.dados).toMatchObject({
      fotoPerfil: url,
      statusVerificacaoCnh: 'APROVADA',
      cnhCategoria: 'AB',
      cnhValidade: '2099-05-01',
      veiculo: { id: 7, modelo: 'Onix' },
    });
    expect(resultado.dados).not.toHaveProperty('cpf');
  });

  it('normaliza e salva os dados do veículo', async () => {
    usersService.buscarPorId.mockResolvedValue({ idUsuario: 1 });
    usersService.salvarVeiculo.mockResolvedValue({
      idVeiculo: 3,
      modelo: 'Onix',
      cor: 'Branco',
      placa: 'ABC1D23',
    });
    const request = {
      usuario: { sub: 1, nome: 'João', email: 'joao@email.com' },
    } as unknown as Request & {
      usuario: { sub: number; nome: string; email: string };
    };

    const resultado = await controller.salvarVeiculo(
      { modelo: ' Onix ', cor: ' Branco ', placa: 'abc-1d23' },
      request,
    );

    expect(usersService.salvarVeiculo).toHaveBeenCalledWith(
      1,
      'Onix',
      'Branco',
      'ABC1D23',
    );
    expect(resultado.dados.placa).toBe('ABC1D23');
  });

  describe('remocao e troca de foto', () => {
    const antiga = 'https://exemplo.com/antiga';
    const nova = 'https://exemplo.com/nova';
    const request = { usuario: { sub: 1 } } as never;
    const usuario = {
      idUsuario: 1,
      fotoPerfil: antiga,
      statusVerificacaoCnh: 'APROVADA',
      cnhCategoria: 'AB',
      cnhValidade: '2099-05-01',
    };

    beforeEach(() => {
      usersService.buscarPorId.mockResolvedValue({ ...usuario });
      usersService.atualizarFotoPerfil.mockImplementation(
        async (atual, fotoPerfil) => ({ ...atual, fotoPerfil }),
      );
      fotoPerfilService.enviar.mockResolvedValue(nova);
    });

    it('remove a foto da propria conta preservando CNH e veiculo', async () => {
      usersService.buscarVeiculo.mockResolvedValue({
        idVeiculo: 7,
        modelo: 'Onix',
      });
      const resultado = await controller.removerFotoPerfil(
        { fotoAtual: antiga, idUsuario: 99 },
        request,
      );
      expect(usersService.buscarPorId).toHaveBeenCalledWith(1);
      expect(usersService.atualizarFotoPerfil).toHaveBeenCalledWith(
        usuario,
        null,
      );
      expect(fotoPerfilService.remover).toHaveBeenCalledWith(1, antiga);
      expect(resultado.dados).toMatchObject({
        fotoPerfil: null,
        statusVerificacaoCnh: 'APROVADA',
        veiculo: { id: 7 },
      });
      expect(resultado).not.toHaveProperty('aviso');
    });

    it('repetir remocao de perfil sem foto nao exclui outros arquivos', async () => {
      usersService.buscarPorId.mockResolvedValue({
        ...usuario,
        fotoPerfil: null,
      });
      expect(
        (await controller.removerFotoPerfil({ fotoAtual: antiga }, request))
          .dados.fotoPerfil,
      ).toBeNull();
      expect(usersService.atualizarFotoPerfil).not.toHaveBeenCalled();
      expect(fotoPerfilService.remover).not.toHaveBeenCalled();
    });

    it.each([
      undefined,
      {},
      { fotoAtual: null },
      { fotoAtual: 1 },
      { fotoAtual: '' },
      { fotoAtual: 'x'.repeat(501) },
    ])('recusa pedido malformado: %j', async (body) => {
      await expect(
        controller.removerFotoPerfil(body, request),
      ).rejects.toBeInstanceOf(BadRequestException);
      expect(usersService.atualizarFotoPerfil).not.toHaveBeenCalled();
      expect(fotoPerfilService.remover).not.toHaveBeenCalled();
    });

    it('remocao antiga nao atinge foto mais recente', async () => {
      usersService.buscarPorId.mockResolvedValue({
        ...usuario,
        fotoPerfil: nova,
      });
      await expect(
        controller.removerFotoPerfil({ fotoAtual: antiga }, request),
      ).rejects.toThrow('outro acesso');
      expect(usersService.atualizarFotoPerfil).not.toHaveBeenCalled();
      expect(fotoPerfilService.remover).not.toHaveBeenCalled();
    });

    it('falha no banco nao apaga arquivo nem anuncia sucesso', async () => {
      usersService.atualizarFotoPerfil.mockRejectedValue(
        new Error('banco indisponivel'),
      );
      await expect(
        controller.removerFotoPerfil({ fotoAtual: antiga }, request),
      ).rejects.toThrow('banco');
      expect(fotoPerfilService.remover).not.toHaveBeenCalled();
    });

    it('limpeza parcial retorna perfil sem foto e aviso explicito', async () => {
      fotoPerfilService.remover.mockRejectedValue(
        new Error('storage indisponivel'),
      );
      const resultado = await controller.removerFotoPerfil(
        { fotoAtual: antiga },
        request,
      );
      expect(resultado.dados.fotoPerfil).toBeNull();
      expect(resultado.aviso).toContain('armazenamento');
    });

    it('troca de foto limpa apenas a antiga depois de salvar a nova', async () => {
      const resultado = await controller.atualizarFotoPerfil(
        { buffer: Buffer.from([0xff, 0xd8, 0xff]) },
        request,
      );
      expect(resultado.dados.fotoPerfil).toBe(nova);
      expect(fotoPerfilService.remover).toHaveBeenCalledWith(1, antiga);
      expect(
        usersService.atualizarFotoPerfil.mock.invocationCallOrder[0],
      ).toBeLessThan(fotoPerfilService.remover.mock.invocationCallOrder[0]);
    });

    it('falha ao persistir upload limpa apenas o novo arquivo e preserva a antiga', async () => {
      usersService.atualizarFotoPerfil.mockRejectedValue(
        new ConflictException('conflito'),
      );
      await expect(
        controller.atualizarFotoPerfil(
          { buffer: Buffer.from([0xff, 0xd8, 0xff]) },
          request,
        ),
      ).rejects.toThrow('conflito');
      expect(fotoPerfilService.remover).toHaveBeenCalledTimes(1);
      expect(fotoPerfilService.remover).toHaveBeenCalledWith(1, nova);
    });

    it('falha ambigua no banco nao exclui foto que pode ter sido persistida', async () => {
      usersService.atualizarFotoPerfil.mockRejectedValue(
        new Error('conexao interrompida'),
      );
      await expect(
        controller.atualizarFotoPerfil(
          { buffer: Buffer.from([0xff, 0xd8, 0xff]) },
          request,
        ),
      ).rejects.toThrow('conexao');
      expect(fotoPerfilService.remover).not.toHaveBeenCalled();
    });
  });

  it.each(['modelo', 'cor', 'placa'])(
    'recusa objeto malformado em %s antes de acessar o banco',
    async (campo) => {
      const body = {
        modelo: 'Honda Civic',
        cor: 'Prata',
        placa: 'ABC1D23',
        [campo]: { toString: 'texto' },
      };
      await expect(
        controller.salvarVeiculo(body, { usuario: { sub: 1 } } as never),
      ).rejects.toBeInstanceOf(BadRequestException);
      expect(usersService.buscarPorId).not.toHaveBeenCalled();
      expect(usersService.salvarVeiculo).not.toHaveBeenCalled();
    },
  );
});
