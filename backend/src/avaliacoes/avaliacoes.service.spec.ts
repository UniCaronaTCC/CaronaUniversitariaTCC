import { NotFoundException } from '@nestjs/common';
import { Repository } from 'typeorm';

import { UsersService } from '../users/users.service';
import { Avaliacao } from './avaliacao.entity';
import { AvaliacoesService } from './avaliacoes.service';

describe('AvaliacoesService', () => {
  let service: AvaliacoesService;
  let avaliacoesRepository: { createQueryBuilder: jest.Mock };
  let usersService: { buscarPorId: jest.Mock };

  beforeEach(() => {
    const resumoQuery = {
      select: jest.fn().mockReturnThis(),
      addSelect: jest.fn().mockReturnThis(),
      where: jest.fn().mockReturnThis(),
      getRawOne: jest.fn().mockResolvedValue({ media: '4.50', total: '2' }),
    };

    const listaQuery = {
      innerJoinAndSelect: jest.fn().mockReturnThis(),
      select: jest.fn().mockReturnThis(),
      where: jest.fn().mockReturnThis(),
      orderBy: jest.fn().mockReturnThis(),
      skip: jest.fn().mockReturnThis(),
      take: jest.fn().mockReturnThis(),
      getMany: jest.fn().mockResolvedValue([
        { idAvaliacao: 1, nota: 5 },
        { idAvaliacao: 2, nota: 4 },
      ]),
    };

    avaliacoesRepository = {
      createQueryBuilder: jest
        .fn()
        .mockReturnValueOnce(resumoQuery)
        .mockReturnValueOnce(listaQuery),
    };
    usersService = {
      buscarPorId: jest.fn().mockResolvedValue({ idUsuario: 1 }),
    };

    service = new AvaliacoesService(
      avaliacoesRepository as unknown as Repository<Avaliacao>,
      usersService as unknown as UsersService,
    );
  });

  it('lista as avaliacoes recebidas com media e paginacao', async () => {
    const resultado = await service.listarRecebidas(1, 1);

    expect(resultado.media).toBe(4.5);
    expect(resultado.total).toBe(2);
    expect(resultado.totalPaginas).toBe(1);
    expect(resultado.avaliacoes).toHaveLength(2);
  });

  it('informa quando o usuario nao existe', async () => {
    usersService.buscarPorId.mockResolvedValue(null);

    await expect(service.listarRecebidas(99, 1)).rejects.toBeInstanceOf(
      NotFoundException,
    );
    expect(avaliacoesRepository.createQueryBuilder).not.toHaveBeenCalled();
  });
});
