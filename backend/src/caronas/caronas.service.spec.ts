import { NotFoundException } from '@nestjs/common';
import { Repository } from 'typeorm';

import { Carona } from './carona.entity';
import { CaronasService, DadosCriacaoCarona } from './caronas.service';

describe('CaronasService', () => {
  let service: CaronasService;
  let repository: {
    create: jest.Mock;
    createQueryBuilder: jest.Mock;
    findOne: jest.Mock;
    save: jest.Mock;
  };
  let queryBuilder: {
    update: jest.Mock;
    set: jest.Mock;
    where: jest.Mock;
    andWhere: jest.Mock;
    execute: jest.Mock;
  };

  const dados: DadosCriacaoCarona = {
    idUsuario: 1,
    origem: 'Rua A',
    origemCidade: 'Araçatuba',
    origemLatitude: -21.2,
    origemLongitude: -50.4,
    destino: 'UniSalesiano',
    destinoCidade: 'Araçatuba',
    destinoLatitude: -21.19,
    destinoLongitude: -50.43,
    dataInicio: '2026-07-25',
    dataFim: null,
    horario: '19:00:00',
    vagas: 3,
    valor: 8.5,
    recorrente: false,
    diasSemana: null,
  };

  beforeEach(() => {
    queryBuilder = {
      update: jest.fn().mockReturnThis(),
      set: jest.fn().mockReturnThis(),
      where: jest.fn().mockReturnThis(),
      andWhere: jest.fn().mockReturnThis(),
      execute: jest.fn().mockResolvedValue(undefined),
    };
    repository = {
      create: jest.fn((carona: Partial<Carona>) => carona as Carona),
      createQueryBuilder: jest.fn((): typeof queryBuilder => queryBuilder),
      findOne: jest.fn(),
      save: jest.fn((carona: Carona) => Promise.resolve(carona)),
    };

    service = new CaronasService(repository as unknown as Repository<Carona>);
  });

  it('atualiza uma carona pertencente ao usuário', async () => {
    repository.findOne.mockResolvedValue({
      idCarona: 5,
      usuario: { idUsuario: 1 },
      status: 'LOTADA',
    });

    const resultado = await service.atualizarCarona(5, dados);

    expect(resultado.destino).toBe('UniSalesiano');
    expect(resultado.status).toBe('ATIVA');
    expect(repository.save).toHaveBeenCalledTimes(1);
  });

  it('não permite atualizar carona de outro usuário', async () => {
    repository.findOne.mockResolvedValue({
      idCarona: 5,
      usuario: { idUsuario: 2 },
    });

    await expect(service.atualizarCarona(5, dados)).rejects.toBeInstanceOf(
      NotFoundException,
    );
    expect(repository.save).not.toHaveBeenCalled();
  });

  it('cancela a carona sem apagar o histórico', async () => {
    const carona = {
      idCarona: 5,
      usuario: { idUsuario: 1 },
      status: 'ATIVA',
    };
    repository.findOne.mockResolvedValue(carona);

    await service.excluirCarona(5, 1);

    expect(carona.status).toBe('CANCELADA');
    expect(repository.save).toHaveBeenCalledWith(carona);
  });

  it('finaliza automaticamente caronas vencidas', async () => {
    await service.finalizarCaronasVencidas();

    expect(queryBuilder.update).toHaveBeenCalledWith(Carona);
    expect(queryBuilder.set).toHaveBeenCalledWith({ status: 'FINALIZADA' });
    expect(queryBuilder.execute).toHaveBeenCalledTimes(1);
  });
});
