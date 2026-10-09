import { BadRequestException } from '@nestjs/common';

import type { RequisicaoComUsuario } from '../auth/requisicao-com-usuario';
import { VerificacaoCnhController } from './verificacao-cnh.controller';
import { VerificacaoCnhService } from './verificacao-cnh.service';

describe('VerificacaoCnhController', () => {
  const requisicao = { usuario: { sub: 7 } } as RequisicaoComUsuario;
  let verificacao: { verificar: jest.Mock };
  let controller: VerificacaoCnhController;

  beforeEach(() => {
    verificacao = {
      verificar: jest.fn().mockResolvedValue({ status: 'APROVADA' }),
    };
    controller = new VerificacaoCnhController(
      verificacao as unknown as VerificacaoCnhService,
    );
  });

  const jpeg = () => Buffer.from([0xff, 0xd8, 0xff, 0x00]);

  it('exige consentimento e apaga os buffers recebidos', async () => {
    const frente = jpeg();
    const verso = jpeg();
    await expect(
      controller.verificar(
        { frente: [{ buffer: frente }], verso: [{ buffer: verso }] },
        { aceitePrivacidade: 'false' },
        requisicao,
      ),
    ).rejects.toBeInstanceOf(BadRequestException);
    expect(verificacao.verificar).not.toHaveBeenCalled();
    expect([...frente, ...verso].every((byte) => byte === 0)).toBe(true);
  });

  it('exige as duas fotos', async () => {
    await expect(
      controller.verificar(
        { frente: [{ buffer: jpeg() }] },
        { aceitePrivacidade: 'true', nomeCompleto: 'João Pedro da Silva' },
        requisicao,
      ),
    ).rejects.toThrow('Envie fotos da frente e do verso da CNH');
  });

  it('recusa assinatura de arquivo inválida', async () => {
    await expect(
      controller.verificar(
        {
          frente: [{ buffer: Buffer.from('invalido') }],
          verso: [{ buffer: jpeg() }],
        },
        { aceitePrivacidade: 'true', nomeCompleto: 'João Pedro da Silva' },
        requisicao,
      ),
    ).rejects.toThrow('Envie fotos JPG, PNG ou WebP');
    expect(verificacao.verificar).not.toHaveBeenCalled();
  });

  it('usa o usuário autenticado e não retorna dados da CNH', async () => {
    const frente = jpeg();
    const verso = jpeg();
    const resultado = await controller.verificar(
      { frente: [{ buffer: frente }], verso: [{ buffer: verso }] },
      { aceitePrivacidade: 'true', nomeCompleto: 'João Pedro da Silva' },
      requisicao,
    );
    expect(verificacao.verificar).toHaveBeenCalledWith(
      7,
      frente,
      verso,
      'João Pedro da Silva',
    );
    expect(resultado.dados).toEqual({ status: 'APROVADA' });
    expect([...frente, ...verso].every((byte) => byte === 0)).toBe(true);
  });
});
