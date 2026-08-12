import { BadRequestException } from '@nestjs/common';

import { InstituicoesController } from './instituicoes.controller';
import { InstituicoesService } from './instituicoes.service';

describe('InstituicoesController', () => {
  let controller: InstituicoesController;
  let service: { buscar: jest.Mock };

  beforeEach(() => {
    service = { buscar: jest.fn() };
    controller = new InstituicoesController(
      service as unknown as InstituicoesService,
    );
  });

  it('retorna as instituições encontradas', async () => {
    service.buscar.mockResolvedValue([
      {
        instituicao: {
          idInstituicao: 1,
          codigoEmec: 123,
          nome: 'Centro Universitário Salesiano',
          sigla: 'UNISALESIANO',
        },
        campus: {
          nome: 'Araçatuba',
          municipio: 'Araçatuba',
          uf: 'SP',
        },
        distanciaKm: 2.5,
      },
    ]);

    const resultado = await controller.buscar('unisalesiano');

    expect(resultado.dados).toEqual([
      {
        id: 1,
        codigoEmec: 123,
        nome: 'Centro Universitário Salesiano',
        sigla: 'UNISALESIANO',
        campus: 'Araçatuba',
        municipio: 'Araçatuba',
        uf: 'SP',
        distanciaKm: 2.5,
      },
    ]);
    expect(service.buscar).toHaveBeenCalledWith(
      'unisalesiano',
      undefined,
      undefined,
      undefined,
      undefined,
    );
  });

  it('exige pelo menos dois caracteres', async () => {
    await expect(controller.buscar('u')).rejects.toBeInstanceOf(
      BadRequestException,
    );
  });
});
