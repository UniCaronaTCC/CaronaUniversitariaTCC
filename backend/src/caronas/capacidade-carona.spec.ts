import {
  BadRequestException,
  ConflictException,
  NotFoundException,
} from '@nestjs/common';
import { DataSource, EntityManager, Repository } from 'typeorm';
import { Carona } from './carona.entity';
import { CaronasService } from './caronas.service';
import { DadosEdicaoCarona } from './dados-carona';
import { PontoEmbarque } from './ponto-embarque.entity';
import { PosicaoAtualCarona } from './posicao-atual-carona.entity';
import { RecorrenciasService } from './recorrencias.service';
import { Solicitacao } from '../solicitacoes/solicitacao.entity';
import { UsersService } from '../users/users.service';

describe('Edicao de capacidade com reservas', () => {
  const dados: DadosEdicaoCarona = {
    idUsuario: 7,
    origem: 'Rua A, 10',
    origemCidade: null,
    origemLatitude: -21,
    origemLongitude: -50,
    destino: 'Campus',
    destinoCidade: null,
    destinoLatitude: -21.1,
    destinoLongitude: -50.1,
    dataInicio: '2099-12-01',
    dataFim: null,
    horario: '18:00:00',
    capacidadePassageiros: 4,
    capacidadeAnterior: 4,
    valor: 5,
    recorrente: false,
    diasSemana: null,
    pontosEmbarque: [
      {
        nome: 'Portaria',
        endereco: 'Rua A, 10',
        latitude: -21,
        longitude: -50,
        ordem: 1,
      },
      {
        nome: null,
        endereco: 'Rua B, 20',
        latitude: -21.1,
        longitude: -50.1,
        ordem: 2,
      },
    ],
    observacoes: 'Nova observacao',
  };

  function preparar(livres = 2, aceitos = 2) {
    const eventos: string[] = [];
    const carona = Object.assign(new Carona(), {
      ...dados,
      idCarona: 10,
      vagas: livres,
      status: livres ? 'ATIVA' : 'LOTADA',
      dataInicio: dados.dataInicio,
      recorrente: false,
      pontosEmbarque: dados.pontosEmbarque
        .map((p, i) =>
          Object.assign(new PontoEmbarque(), p, { idPontoEmbarque: i + 1 }),
        )
        .reverse(),
    });
    const getOne = jest
      .fn<Promise<Carona | null>, []>()
      .mockImplementation(() => {
        eventos.push('bloqueio');
        return Promise.resolve(carona);
      });
    const qb = {
      where: jest.fn().mockReturnThis(),
      andWhere: jest.fn().mockReturnThis(),
      setLock: jest.fn().mockReturnThis(),
      getOne,
    };
    const save = jest.fn<Promise<Carona>, [Carona]>().mockResolvedValue(carona);
    const count = jest
      .fn<Promise<number>, [unknown]>()
      .mockImplementation(() => {
        eventos.push('contagem');
        return Promise.resolve(aceitos);
      });
    const repo = {
      createQueryBuilder: () => qb,
      save,
      findOneOrFail: jest
        .fn<Promise<Carona>, [unknown]>()
        .mockResolvedValue(carona),
    };
    const manager = {
      getRepository: (e: unknown) =>
        e === Carona
          ? repo
          : e === PontoEmbarque
            ? {
                find: jest
                  .fn()
                  .mockResolvedValue(
                    [...carona.pontosEmbarque].sort(
                      (a, b) => a.ordem - b.ordem,
                    ),
                  ),
              }
            : { count },
    } as unknown as EntityManager;
    const transaction = jest
      .fn<Promise<unknown>, [(m: EntityManager) => Promise<unknown>]>()
      .mockImplementation((executar) => executar(manager));
    const service = new CaronasService(
      {} as Repository<Carona>,
      {} as Repository<PontoEmbarque>,
      {} as Repository<PosicaoAtualCarona>,
      {} as Repository<Solicitacao>,
      { transaction } as unknown as DataSource,
      {} as UsersService,
      {} as RecorrenciasService,
    );
    return { service, carona, qb, save, count, eventos, transaction, manager };
  }

  it.each([
    [2, 2, 4, 2, 'ATIVA'],
    [1, 2, 4, 2, 'ATIVA'],
    [4, 0, 2, 2, 'ATIVA'],
    [0, 4, 4, 0, 'LOTADA'],
    [0, 2, 4, 2, 'ATIVA'],
    [1, 0, 1, 1, 'ATIVA'],
    [1, 0, 4, 4, 'ATIVA'],
  ])(
    'livres %i, aceitos %i, capacidade %i -> livres %i (%s)',
    async (livres, aceitos, total, esperado, status) => {
      const h = preparar(livres, aceitos);
      const resultado = await h.service.atualizarCarona(10, {
        ...dados,
        capacidadePassageiros: total,
        capacidadeAnterior: livres + aceitos,
      });
      expect(resultado.vagas).toBe(esperado);
      expect(resultado.status).toBe(status);
      expect(resultado.observacoes).toBe(dados.observacoes);
      expect(resultado.pontosEmbarque.map((p) => p.ordem)).toEqual([1, 2]);
      expect(h.save).toHaveBeenCalledTimes(1);
      expect(h.eventos).toEqual(['bloqueio', 'contagem']);
      expect(h.qb.setLock).toHaveBeenCalledWith('pessimistic_write');
      expect(h.count).toHaveBeenCalledWith({
        where: { carona: { idCarona: 10 }, status: 'ACEITA' },
      });
    },
  );

  it('consulta capacidade para o proprietario com a contagem atual', async () => {
    const h = preparar();
    await expect(h.service.buscarCapacidade(10, 7)).resolves.toEqual({
      capacidadePassageiros: 4,
      passageirosAceitos: 2,
      vagasDisponiveis: 2,
    });
    expect(h.save).not.toHaveBeenCalled();
    expect(h.qb.andWhere).toHaveBeenCalledWith(
      'carona.id_usuario = :idUsuario',
      { idUsuario: 7 },
    );
  });

  it('recusa consulta ou edicao sem carona do proprietario', async () => {
    const h = preparar();
    h.qb.getOne.mockResolvedValue(null);
    await expect(h.service.buscarCapacidade(10, 99)).rejects.toBeInstanceOf(
      NotFoundException,
    );
    await expect(h.service.atualizarCarona(10, dados)).rejects.toBeInstanceOf(
      NotFoundException,
    );
    expect(h.count).not.toHaveBeenCalled();
    expect(h.save).not.toHaveBeenCalled();
  });

  it.each(['EM_ANDAMENTO', 'FINALIZADA', 'CANCELADA'] as const)(
    'bloqueia consulta e edicao em %s',
    async (status) => {
      const h = preparar();
      h.carona.status = status;
      await expect(h.service.buscarCapacidade(10, 7)).rejects.toBeInstanceOf(
        ConflictException,
      );
      await expect(h.service.atualizarCarona(10, dados)).rejects.toBeInstanceOf(
        ConflictException,
      );
      expect(h.save).not.toHaveBeenCalled();
    },
  );

  it.each([0, -1, 5, 1.5, NaN])(
    'recusa capacidade invalida %s',
    async (total) => {
      const h = preparar();
      await expect(
        h.service.atualizarCarona(10, {
          ...dados,
          capacidadePassageiros: total,
        }),
      ).rejects.toBeInstanceOf(BadRequestException);
      expect(h.save).not.toHaveBeenCalled();
    },
  );

  it.each([
    [-1, 2],
    [3, 2],
    [0, 0],
  ])(
    'nao adivinha reparo para estado inconsistente %j',
    async (livres, aceitos) => {
      const h = preparar(livres, aceitos);
      await expect(h.service.atualizarCarona(10, dados)).rejects.toThrow(
        'inconsistentes',
      );
      expect(h.save).not.toHaveBeenCalled();
    },
  );

  it('aceite ocorrido apos abrir a tela nao recria a vaga ocupada', async () => {
    const h = preparar(1, 3);
    const r = await h.service.atualizarCarona(10, {
      ...dados,
      capacidadePassageiros: 4,
    });
    expect(r.vagas).toBe(1);
    expect(r.status).toBe('ATIVA');
  });

  it('recusa reducao quando novos aceites ultrapassam a capacidade escolhida', async () => {
    const h = preparar(1, 3);
    await expect(
      h.service.atualizarCarona(10, { ...dados, capacidadePassageiros: 2 }),
    ).rejects.toThrow('passageiros aceitos');
    expect(h.carona.vagas).toBe(1);
    expect(h.save).not.toHaveBeenCalled();
  });

  it.each(['cancelamento', 'expiracao'])(
    'recalcula com a vaga devolvida por %s',
    async () => {
      const h = preparar(3, 1);
      const r = await h.service.atualizarCarona(10, {
        ...dados,
        capacidadePassageiros: 4,
      });
      expect(r.vagas).toBe(3);
    },
  );

  it('recusa sobrescrever capacidade alterada por outra edicao', async () => {
    const h = preparar(1, 2);
    await expect(h.service.atualizarCarona(10, dados)).rejects.toThrow(
      'outra edição',
    );
    expect(h.save).not.toHaveBeenCalled();
  });

  it('duas edicoes concorrentes em transacoes serializadas nao se sobrescrevem', async () => {
    const h = preparar(1, 1);
    // Simula a serializacao do bloqueio de linha, sem usar o banco real.
    let fila = Promise.resolve();
    h.transaction.mockImplementation((executar) => {
      const atual = fila.then(() => executar(h.manager));
      fila = atual.then(
        () => undefined,
        () => undefined,
      );
      return atual;
    });
    const primeira = h.service.atualizarCarona(10, {
      ...dados,
      capacidadePassageiros: 3,
      capacidadeAnterior: 2,
    });
    const segunda = h.service.atualizarCarona(10, {
      ...dados,
      capacidadePassageiros: 4,
      capacidadeAnterior: 2,
    });
    await expect(primeira).resolves.toMatchObject({ vagas: 2 });
    await expect(segunda).rejects.toThrow('outra edição');
    expect(h.save).toHaveBeenCalledTimes(1);
  });

  it('preserva a protecao da programacao recorrente', async () => {
    const h = preparar();
    h.carona.recorrente = true;
    await expect(h.service.atualizarCarona(10, dados)).rejects.toThrow(
      'Recorrências',
    );
    expect(h.save).not.toHaveBeenCalled();
  });

  it('nao muda a data de uma ocorrencia ja gerada', async () => {
    const h = preparar();
    h.carona.idRecorrencia = 20;
    await expect(
      h.service.atualizarCarona(10, { ...dados, dataInicio: '2099-12-02' }),
    ).rejects.toThrow('programação');
    expect(h.save).not.toHaveBeenCalled();
  });

  it.each([
    { origem: 'Outra rua' },
    { origemCidade: 'Outra cidade' },
    { origemLatitude: -22 },
    { origemLongitude: -51 },
    { destino: 'Outro campus' },
    { destinoCidade: 'Outra cidade' },
    { destinoLatitude: -22 },
    { destinoLongitude: -51 },
    { dataInicio: '2099-12-02' },
    { dataFim: '2099-12-02' },
    { horario: '19:00:00' },
    { valor: 10 },
    { pontosEmbarque: [] },
    { pontosEmbarque: [...dados.pontosEmbarque].reverse() },
    {
      pontosEmbarque: dados.pontosEmbarque.map((p) => ({
        ...p,
        nome: 'Outro ponto',
      })),
    },
    {
      pontosEmbarque: dados.pontosEmbarque.map((p) => ({
        ...p,
        endereco: 'Outro endereco',
      })),
    },
    {
      pontosEmbarque: dados.pontosEmbarque.map((p) => ({
        ...p,
        latitude: -22,
      })),
    },
    {
      pontosEmbarque: dados.pontosEmbarque.map((p) => ({
        ...p,
        longitude: -51,
      })),
    },
  ])('bloqueia alteracao de dados confirmados: %j', async (alteracao) => {
    const h = preparar();
    await expect(
      h.service.atualizarCarona(10, { ...dados, ...alteracao }),
    ).rejects.toThrow('Apenas observações');
    expect(h.save).not.toHaveBeenCalled();
    expect(h.carona.vagas).toBe(2);
    expect(h.carona.valor).toBe(5);
  });

  it.each([2, 3])(
    'com aceitos nao permite reduzir capacidade para %i mesmo havendo vagas',
    async (total) => {
      const h = preparar();
      await expect(
        h.service.atualizarCarona(10, {
          ...dados,
          capacidadePassageiros: total,
        }),
      ).rejects.toThrow('só pode ser aumentada');
      expect(h.save).not.toHaveBeenCalled();
    },
  );

  it('sem aceitos permite editar os dados da viagem e reduzir capacidade', async () => {
    const h = preparar(4, 0);
    const r = await h.service.atualizarCarona(10, {
      ...dados,
      destino: 'Outro campus',
      horario: '19:00:00',
      valor: 10,
      capacidadePassageiros: 1,
    });
    expect(r.destino).toBe('Outro campus');
    expect(r.horario).toBe('19:00:00');
    expect(r.valor).toBe(10);
    expect(r.vagas).toBe(1);
  });

  it('novo aceite durante a edicao bloqueia mudanca de preco', async () => {
    const h = preparar(4, 0);
    await expect(h.service.buscarCapacidade(10, 7)).resolves.toMatchObject({
      passageirosAceitos: 0,
    });
    h.carona.vagas = 3;
    h.count.mockResolvedValue(1);
    await expect(
      h.service.atualizarCarona(10, { ...dados, valor: 10 }),
    ).rejects.toThrow('Reabra a carona');
    expect(h.carona.valor).toBe(5);
    expect(h.save).not.toHaveBeenCalled();
  });

  it('novo aceite durante a edicao permite observacoes sem mudar os dados confirmados', async () => {
    const h = preparar(4, 0);
    await h.service.buscarCapacidade(10, 7);
    h.carona.vagas = 3;
    h.count.mockResolvedValue(1);
    const r = await h.service.atualizarCarona(10, dados);
    expect(r.vagas).toBe(3);
    expect(r.observacoes).toBe(dados.observacoes);
    expect(r.destino).toBe(dados.destino);
    expect(r.valor).toBe(5);
  });
});
