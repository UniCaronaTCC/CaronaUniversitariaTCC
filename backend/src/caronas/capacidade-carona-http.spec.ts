import {
  ConflictException,
  INestApplication,
  NotFoundException,
} from '@nestjs/common';
import { Test } from '@nestjs/testing';
import { Server } from 'node:http';
import request from 'supertest';
import { SupabaseAuthService } from '../auth/supabase-auth.service';
import { UsersService } from '../users/users.service';
import { Carona } from './carona.entity';
import { CaronasController } from './caronas.controller';
import { CaronasService } from './caronas.service';

describe('HTTP de capacidade (sem banco real)', () => {
  let app: INestApplication<Server>;
  const capacidade = {
    capacidadePassageiros: 4,
    passageirosAceitos: 4,
    vagasDisponiveis: 0,
  };
  const service = {
    buscarCapacidade: jest.fn<
      ReturnType<CaronasService['buscarCapacidade']>,
      Parameters<CaronasService['buscarCapacidade']>
    >(),
    atualizarCarona: jest.fn<
      ReturnType<CaronasService['atualizarCarona']>,
      Parameters<CaronasService['atualizarCarona']>
    >(),
    buscarDetalhesCarona: jest.fn(),
  };
  const body = {
    origem: 'Rua A, 10',
    origemLatitude: -21,
    origemLongitude: -50,
    destino: 'Campus',
    destinoLatitude: -21.1,
    destinoLongitude: -50.1,
    dataInicio: '2099-12-01',
    horario: '18:00:00',
    valor: 5,
    recorrente: false,
    capacidadePassageiros: 4,
    capacidadeAnterior: 4,
  };
  beforeAll(async () => {
    const module = await Test.createTestingModule({
      controllers: [CaronasController],
      providers: [
        { provide: CaronasService, useValue: service },
        {
          provide: SupabaseAuthService,
          useValue: {
            buscarUsuario: () => Promise.resolve({ authId: 'id-sintetico' }),
          },
        },
        {
          provide: UsersService,
          useValue: {
            buscarPorAuthId: () =>
              Promise.resolve({
                idUsuario: 7,
                email: 'teste@example.com',
                nome: 'Teste',
              }),
          },
        },
      ],
    }).compile();
    app = module.createNestApplication<INestApplication<Server>>({
      logger: false,
    });
    await app.init();
  });
  afterAll(async () => {
    await app.close();
  });
  beforeEach(() => {
    jest.clearAllMocks();
    service.buscarCapacidade.mockResolvedValue(capacidade);
    service.atualizarCarona.mockResolvedValue(
      Object.assign(new Carona(), {
        idCarona: 10,
        vagas: 0,
        status: 'LOTADA',
        pontosEmbarque: [],
        usuario: { idUsuario: 7, nome: 'Teste', veiculo: null },
      }),
    );
  });

  it('GET de capacidade usa a rota especifica e o usuario autenticado', async () => {
    await request(app.getHttpServer())
      .get('/caronas/10/capacidade')
      .set('Authorization', 'Bearer sintetico')
      .expect(200)
      .expect({ sucesso: true, dados: capacidade });
    expect(service.buscarCapacidade).toHaveBeenCalledWith(10, 7);
    expect(service.buscarDetalhesCarona).not.toHaveBeenCalled();
  });

  it.each(['get', 'patch'] as const)(
    'exige autenticacao em %s',
    async (metodo) => {
      const rota = metodo === 'get' ? '/caronas/10/capacidade' : '/caronas/10';
      await request(app.getHttpServer())[metodo](rota).send(body).expect(401);
      expect(service.buscarCapacidade).not.toHaveBeenCalled();
      expect(service.atualizarCarona).not.toHaveBeenCalled();
    },
  );

  it.each(['0', '-1', 'abc', '1.2'])('recusa id invalido %s', async (id) => {
    await request(app.getHttpServer())
      .get(`/caronas/${id}/capacidade`)
      .set('Authorization', 'Bearer sintetico')
      .expect(400);
    expect(service.buscarCapacidade).not.toHaveBeenCalled();
  });

  it('PATCH aceita editar carona lotada sem interpretar capacidade como vagas', async () => {
    await request(app.getHttpServer())
      .patch('/caronas/10')
      .set('Authorization', 'Bearer sintetico')
      .send({ ...body, vagas: 99, idUsuario: 99 })
      .expect(200);
    const [id, dados] = service.atualizarCarona.mock.calls[0];
    expect(id).toBe(10);
    expect(dados.idUsuario).toBe(7);
    expect(dados.capacidadePassageiros).toBe(4);
    expect(dados).not.toHaveProperty('vagas');
  });

  it('PATCH antigo recebe orientacao de atualizar em vez de alterar vagas', async () => {
    const antigo = { ...body, vagas: 4 } as Record<string, unknown>;
    delete antigo.capacidadePassageiros;
    delete antigo.capacidadeAnterior;
    await request(app.getHttpServer())
      .patch('/caronas/10')
      .set('Authorization', 'Bearer sintetico')
      .send(antigo)
      .expect(409);
    expect(service.atualizarCarona).not.toHaveBeenCalled();
  });

  it('PATCH invalido nao chega ao servico', async () => {
    await request(app.getHttpServer())
      .patch('/caronas/10')
      .set('Authorization', 'Bearer sintetico')
      .send({ ...body, capacidadePassageiros: '4' })
      .expect(400);
    expect(service.atualizarCarona).not.toHaveBeenCalled();
  });

  it('propaga conflito de nova reserva como 409', async () => {
    service.atualizarCarona.mockRejectedValueOnce(
      new ConflictException('Reabra a carona'),
    );
    await request(app.getHttpServer())
      .patch('/caronas/10')
      .set('Authorization', 'Bearer sintetico')
      .send(body)
      .expect(409);
  });

  it('consulta sem propriedade nao expoe a ocupacao', async () => {
    service.buscarCapacidade.mockRejectedValueOnce(
      new NotFoundException('Carona nao encontrada'),
    );
    await request(app.getHttpServer())
      .get('/caronas/10/capacidade')
      .set('Authorization', 'Bearer sintetico')
      .expect(404);
  });
});
