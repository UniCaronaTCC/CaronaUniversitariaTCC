import { BadRequestException } from '@nestjs/common';

import { CaronasController } from './caronas.controller';
import { CaronasService } from './caronas.service';

describe('CaronasController', () => {
  it('não retorna senha nem hash ao criar uma carona', async () => {
    const carona = {
      idCarona: 1,
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
      observacoes: null,
      status: 'ATIVA',
      usuario: {
        idUsuario: 1,
        nome: 'João',
        senha: 'hash-que-nao-pode-sair',
        veiculo: {
          modelo: 'Onix',
          cor: 'Branco',
          placa: 'ABC1D23',
        },
      },
    };
    const service = {
      criarCarona: jest.fn().mockResolvedValue(carona),
    };
    const controller = new CaronasController(
      service as unknown as CaronasService,
    );

    const resultado = await controller.criarCarona(
      {
        origem: carona.origem,
        origemLatitude: carona.origemLatitude,
        origemLongitude: carona.origemLongitude,
        destino: carona.destino,
        destinoLatitude: carona.destinoLatitude,
        destinoLongitude: carona.destinoLongitude,
        dataInicio: carona.dataInicio,
        horario: carona.horario,
        vagas: carona.vagas,
        valor: carona.valor,
        recorrente: false,
      },
      { usuario: { sub: 1 } } as never,
    );

    expect(JSON.stringify(resultado)).not.toContain('senha');
    expect(JSON.stringify(resultado)).not.toContain('hash-que-nao-pode-sair');
    expect(resultado.dados.usuario.veiculo).toEqual({
      modelo: 'Onix',
      cor: 'Branco',
      placa: '***1D23',
    });
    expect(JSON.stringify(resultado)).not.toContain('ABC1D23');
  });

  it('não permite oferecer mais de quatro vagas', async () => {
    const service = { criarCarona: jest.fn() };
    const controller = new CaronasController(
      service as unknown as CaronasService,
    );

    await expect(
      controller.criarCarona(
        {
          origem: 'Rua A',
          origemLatitude: -21.2,
          origemLongitude: -50.4,
          destino: 'UniSalesiano',
          destinoLatitude: -21.19,
          destinoLongitude: -50.43,
          dataInicio: '2026-07-25',
          horario: '19:00:00',
          vagas: 5,
          valor: 8.5,
          recorrente: false,
        },
        { usuario: { sub: 1 } } as never,
      ),
    ).rejects.toBeInstanceOf(BadRequestException);

    expect(service.criarCarona).not.toHaveBeenCalled();
  });

  it('mascara a placa nas listagens de caronas', async () => {
    const carona = {
      idCarona: 1,
      origem: 'Rua A',
      origemCidade: 'Araçatuba',
      origemLatitude: -21.2,
      origemLongitude: -50.4,
      destino: 'UniSalesiano',
      destinoCidade: 'Araçatuba',
      destinoLatitude: -21.19,
      destinoLongitude: -50.43,
      dataInicio: '2026-09-21',
      dataFim: null,
      horario: '19:00:00',
      vagas: 3,
      valor: 8.5,
      recorrente: false,
      diasSemana: null,
      observacoes: null,
      status: 'ATIVA',
      pontosEmbarque: [],
      usuario: {
        idUsuario: 2,
        nome: 'Maria',
        veiculo: {
          modelo: 'Onix',
          cor: 'Branco',
          placa: 'ABC1D23',
        },
      },
    };
    const service = {
      listarCaronas: jest.fn().mockResolvedValue([carona]),
      listarMinhasCaronas: jest.fn().mockResolvedValue([carona]),
    };
    const controller = new CaronasController(
      service as unknown as CaronasService,
    );
    const request = { usuario: { sub: 1 } } as never;

    const disponiveis = await controller.listarCaronas(request);
    const minhas = await controller.listarMinhasCaronas(request);

    expect(disponiveis.dados[0].usuario.veiculo.placa).toBe('***1D23');
    expect(minhas.dados[0].usuario.veiculo.placa).toBe('***1D23');
    expect(JSON.stringify(disponiveis)).not.toContain('ABC1D23');
    expect(JSON.stringify(minhas)).not.toContain('ABC1D23');
  });

  it('recusa coordenadas inválidas ao atualizar a posição', async () => {
    const service = { atualizarPosicaoAtual: jest.fn() };
    const controller = new CaronasController(
      service as unknown as CaronasService,
    );

    await expect(
      controller.atualizarPosicaoAtual(
        '5',
        {
          latitude: 95,
          longitude: -50.4,
          direcao: 90,
          precisao: 8,
        },
        { usuario: { sub: 1 } } as never,
      ),
    ).rejects.toBeInstanceOf(BadRequestException);

    expect(service.atualizarPosicaoAtual).not.toHaveBeenCalled();
  });
});
