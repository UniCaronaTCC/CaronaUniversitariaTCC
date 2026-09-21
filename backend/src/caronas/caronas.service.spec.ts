import {
  BadRequestException,
  ConflictException,
  ForbiddenException,
  NotFoundException,
} from '@nestjs/common';
import { DataSource, Repository } from 'typeorm';

import { Carona } from './carona.entity';
import { CaronasService, DadosCriacaoCarona } from './caronas.service';
import { PontoEmbarque } from './ponto-embarque.entity';
import { PosicaoAtualCarona } from './posicao-atual-carona.entity';
import { Solicitacao } from '../solicitacoes/solicitacao.entity';
import { UsersService } from '../users/users.service';

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
  let posicoesRepository: {
    create: jest.Mock;
    delete: jest.Mock;
    findOne: jest.Mock;
    save: jest.Mock;
  };
  let solicitacoesRepository: {
    exists: jest.Mock;
  };
  let usersService: {
    buscarVeiculo: jest.Mock;
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
    pontosEmbarque: [],
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
    posicoesRepository = {
      create: jest.fn(
        (posicao: Partial<PosicaoAtualCarona>) => posicao as PosicaoAtualCarona,
      ),
      delete: jest.fn().mockResolvedValue(undefined),
      findOne: jest.fn(),
      save: jest.fn((posicao: PosicaoAtualCarona) => Promise.resolve(posicao)),
    };
    solicitacoesRepository = {
      exists: jest.fn().mockResolvedValue(false),
    };
    usersService = {
      buscarVeiculo: jest.fn().mockResolvedValue({ idVeiculo: 1 }),
    };

    service = new CaronasService(
      repository as unknown as Repository<Carona>,
      {} as Repository<PontoEmbarque>,
      posicoesRepository as unknown as Repository<PosicaoAtualCarona>,
      solicitacoesRepository as unknown as Repository<Solicitacao>,
      {} as DataSource,
      usersService as unknown as UsersService,
    );
  });

  it('não cria carona sem veículo cadastrado', async () => {
    usersService.buscarVeiculo.mockResolvedValue(null);

    await expect(service.criarCarona(dados)).rejects.toThrow(
      'Cadastre seu veículo no perfil antes de oferecer uma carona',
    );
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

  it('inicia uma carona dentro da janela permitida', async () => {
    const carona = {
      idCarona: 5,
      usuario: { idUsuario: 1 },
      recorrente: false,
      status: 'ATIVA',
      dataInicio: '2026-07-25',
      horario: '18:00:00',
      pontosEmbarque: [],
    } as Carona;
    repository.findOne.mockResolvedValue(carona);

    const resultado = await service.iniciarCarona(
      5,
      1,
      new Date('2026-07-25T21:30:00Z'),
    );

    expect(resultado.status).toBe('EM_ANDAMENTO');
    expect(repository.save).toHaveBeenCalledWith(carona);
  });

  it('não inicia fora da janela permitida', async () => {
    repository.findOne.mockResolvedValue({
      idCarona: 5,
      usuario: { idUsuario: 1 },
      recorrente: false,
      status: 'ATIVA',
      dataInicio: '2026-07-25',
      horario: '18:00:00',
      pontosEmbarque: [],
    });

    await expect(
      service.iniciarCarona(5, 1, new Date('2026-07-25T16:00:00Z')),
    ).rejects.toBeInstanceOf(ConflictException);
    expect(repository.save).not.toHaveBeenCalled();
  });

  it('não inicia uma carona recorrente', async () => {
    repository.findOne.mockResolvedValue({
      idCarona: 5,
      usuario: { idUsuario: 1 },
      recorrente: true,
      status: 'ATIVA',
      pontosEmbarque: [],
    });

    await expect(service.iniciarCarona(5, 1)).rejects.toBeInstanceOf(
      BadRequestException,
    );
  });

  it('finaliza uma corrida em andamento', async () => {
    const carona = {
      idCarona: 5,
      usuario: { idUsuario: 1 },
      recorrente: false,
      status: 'EM_ANDAMENTO',
      pontosEmbarque: [],
    } as Carona;
    repository.findOne.mockResolvedValue(carona);

    const resultado = await service.finalizarCarona(5, 1);

    expect(resultado.status).toBe('FINALIZADA');
    expect(repository.save).toHaveBeenCalledWith(carona);
    expect(posicoesRepository.delete).toHaveBeenCalledWith({ idCarona: 5 });
  });

  it('salva a posição atual enviada pelo motorista', async () => {
    repository.findOne.mockResolvedValue({
      idCarona: 5,
      usuario: { idUsuario: 1 },
      status: 'EM_ANDAMENTO',
      pontosEmbarque: [],
    });
    posicoesRepository.findOne.mockResolvedValue(null);

    const resultado = await service.atualizarPosicaoAtual(5, 1, {
      latitude: -21.2,
      longitude: -50.4,
      direcao: 90,
      precisao: 8,
    });

    expect(resultado).toMatchObject({
      idCarona: 5,
      latitude: -21.2,
      longitude: -50.4,
      direcao: 90,
      precisao: 8,
    });
    expect(posicoesRepository.save).toHaveBeenCalledTimes(1);
  });

  it('não atualiza a posição de uma corrida que não está em andamento', async () => {
    repository.findOne.mockResolvedValue({
      idCarona: 5,
      usuario: { idUsuario: 1 },
      status: 'ATIVA',
      pontosEmbarque: [],
    });

    await expect(
      service.atualizarPosicaoAtual(5, 1, {
        latitude: -21.2,
        longitude: -50.4,
        direcao: null,
        precisao: 8,
      }),
    ).rejects.toBeInstanceOf(ConflictException);
    expect(posicoesRepository.save).not.toHaveBeenCalled();
  });

  it('permite que passageiro aceito consulte a posição atual', async () => {
    const posicao = {
      idCarona: 5,
      latitude: -21.2,
      longitude: -50.4,
    } as PosicaoAtualCarona;
    repository.findOne.mockResolvedValue({
      idCarona: 5,
      usuario: { idUsuario: 1 },
      status: 'EM_ANDAMENTO',
    });
    solicitacoesRepository.exists.mockResolvedValue(true);
    posicoesRepository.findOne.mockResolvedValue(posicao);

    await expect(service.buscarPosicaoAtual(5, 2)).resolves.toBe(posicao);
    expect(solicitacoesRepository.exists).toHaveBeenCalledWith({
      where: {
        carona: { idCarona: 5 },
        passageiro: { idUsuario: 2 },
        status: 'ACEITA',
      },
    });
  });

  it('impede usuário sem vaga aceita de consultar a posição', async () => {
    repository.findOne.mockResolvedValue({
      idCarona: 5,
      usuario: { idUsuario: 1 },
      status: 'EM_ANDAMENTO',
    });

    await expect(service.buscarPosicaoAtual(5, 3)).rejects.toBeInstanceOf(
      ForbiddenException,
    );
    expect(posicoesRepository.findOne).not.toHaveBeenCalled();
  });

  it('não edita uma corrida em andamento', async () => {
    repository.findOne.mockResolvedValue({
      idCarona: 5,
      usuario: { idUsuario: 1 },
      status: 'EM_ANDAMENTO',
      pontosEmbarque: [],
    });

    await expect(service.atualizarCarona(5, dados)).rejects.toBeInstanceOf(
      ConflictException,
    );
  });
});
