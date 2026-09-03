import { BadRequestException } from '@nestjs/common';

import type { RequisicaoComUsuario } from '../auth/requisicao-com-usuario';
import { PagamentosController } from './pagamentos.controller';
import { PagamentosService } from './pagamentos.service';

describe('PagamentosController', () => {
  let controller: PagamentosController;
  let pagamentosService: { criarOuObterPix: jest.Mock };

  beforeEach(() => {
    pagamentosService = {
      criarOuObterPix: jest.fn().mockResolvedValue({
        idPagamento: 30,
        solicitacao: { idSolicitacao: 10 },
        metodo: 'PIX',
        valorCentavos: 1250,
        statusCriacao: 'CONFIRMADA',
        statusProvedor: 'PENDING',
        pixCopiaECola: 'codigo-pix',
        qrCodeBase64: 'qr-base64',
        expiraEm: new Date('2026-09-04T12:00:00.000Z'),
        modoTeste: true,
      }),
    };

    controller = new PagamentosController(
      pagamentosService as unknown as PagamentosService,
    );
  });

  it('usa o passageiro autenticado e retorna somente os dados do Pix', async () => {
    const request = {
      usuario: { sub: 1, nome: 'Passageiro', email: 'p@email.com' },
    } as RequisicaoComUsuario;

    const resultado = await controller.criarOuObterPix('10', request);

    expect(pagamentosService.criarOuObterPix).toHaveBeenCalledWith(10, 1);
    expect(resultado).toEqual({
      sucesso: true,
      dados: {
        id: 30,
        idSolicitacao: 10,
        metodo: 'PIX',
        valorCentavos: 1250,
        statusCriacao: 'CONFIRMADA',
        status: 'PENDING',
        pixCopiaECola: 'codigo-pix',
        qrCodeBase64: 'qr-base64',
        expiraEm: new Date('2026-09-04T12:00:00.000Z'),
        modoTeste: true,
      },
    });
  });

  it.each(['abc', '0', '-1', '1.5'])('recusa o id invalido %s', async (id) => {
    const request = {
      usuario: { sub: 1, nome: 'Passageiro', email: 'p@email.com' },
    } as RequisicaoComUsuario;

    await expect(
      controller.criarOuObterPix(id, request),
    ).rejects.toBeInstanceOf(BadRequestException);
    expect(pagamentosService.criarOuObterPix).not.toHaveBeenCalled();
  });
});
