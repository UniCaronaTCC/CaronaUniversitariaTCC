import { BadRequestException } from '@nestjs/common';

import { Avaliacao } from './avaliacao.entity';
import { AvaliacoesController } from './avaliacoes.controller';
import { AvaliacoesService } from './avaliacoes.service';

describe('AvaliacoesController', () => {
  let controller: AvaliacoesController;
  let avaliacoesService: { listarRecebidas: jest.Mock };

  beforeEach(() => {
    avaliacoesService = {
      listarRecebidas: jest.fn().mockResolvedValue({
        media: 5,
        total: 1,
        pagina: 1,
        totalPaginas: 1,
        avaliacoes: [
          {
            idAvaliacao: 1,
            nota: 5,
            comentario: 'Boa carona',
            criadoEm: new Date('2026-08-10T12:00:00.000Z'),
            avaliador: {
              idUsuario: 2,
              nome: 'Maria',
              email: 'maria@email.com',
              senha: 'hash-que-nao-deve-sair',
            },
          } as Avaliacao,
        ],
      }),
    };

    controller = new AvaliacoesController(
      avaliacoesService as unknown as AvaliacoesService,
    );
  });

  it('retorna somente os dados publicos das avaliacoes', async () => {
    const resultado = await controller.listarRecebidas('1');

    expect(resultado.dados.media).toBe(5);
    expect(resultado.dados.avaliacoes[0].avaliador).toEqual({
      id: 2,
      nome: 'Maria',
    });
    expect(resultado.dados.avaliacoes[0].avaliador).not.toHaveProperty('email');
    expect(resultado.dados.avaliacoes[0].avaliador).not.toHaveProperty('senha');
  });

  it('recusa usuario ou pagina invalidos', async () => {
    await expect(controller.listarRecebidas('abc')).rejects.toBeInstanceOf(
      BadRequestException,
    );
    await expect(controller.listarRecebidas('1', '0')).rejects.toBeInstanceOf(
      BadRequestException,
    );
    expect(avaliacoesService.listarRecebidas).not.toHaveBeenCalled();
  });
});
