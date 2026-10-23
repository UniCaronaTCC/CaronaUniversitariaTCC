import { BadRequestException } from '@nestjs/common';
import type { RequisicaoComUsuario } from '../auth/requisicao-com-usuario';
import { VerificacaoCnhController } from './verificacao-cnh.controller';
import { VerificacaoCnhService } from './verificacao-cnh.service';

describe('VerificacaoCnhController ML Kit', () => {
  const req = { usuario: { sub: 7 } } as RequisicaoComUsuario;
  const verificar = jest.fn().mockResolvedValue({ status: 'APROVADA' });
  const reiniciarParaTeste = jest
    .fn()
    .mockResolvedValue({ status: 'NAO_ENVIADA' });
  const controller = new VerificacaoCnhController({
    verificar,
    reiniciarParaTeste,
  } as unknown as VerificacaoCnhService);
  beforeEach(() => jest.clearAllMocks());
  it('usa conta autenticada e não devolve OCR', async () => {
    const leitura = { largura: 1000, altura: 800, linhas: [] };
    const r = await controller.verificar(
      {
        versaoLeitura: 'mlkit-v1',
        aceitePrivacidade: true,
        leitura,
        idUsuario: 99,
      },
      req,
    );
    expect(verificar).toHaveBeenCalledWith(7, leitura);
    expect(r.dados).toEqual({ status: 'APROVADA' });
  });
  it.each([
    {},
    { versaoLeitura: 'mlkit-v1', aceitePrivacidade: 'true' },
    { aceitePrivacidade: true },
  ])('exige novo contrato e aceite booleano', async (body) => {
    await expect(controller.verificar(body, req)).rejects.toBeInstanceOf(
      BadRequestException,
    );
    expect(verificar).not.toHaveBeenCalled();
  });
  it('preserva reinício da própria conta', async () => {
    await controller.reiniciarTeste(req);
    expect(reiniciarParaTeste).toHaveBeenCalledWith(7);
  });
  it('explica a etapa que falhou sem expor o nome lido', async () => {
    verificar.mockResolvedValueOnce({
      status: 'RECUSADA',
      motivo: 'CPF_NAO_LIDO',
    });
    const resposta = await controller.verificar(
      {
        versaoLeitura: 'mlkit-v1',
        aceitePrivacidade: true,
        nomeCompleto: 'Maria Silva',
        leitura: {},
      },
      req,
    );
    expect(resposta.mensagem).toContain('CPF');
    expect(resposta.mensagem).not.toContain('Maria Silva');
  });
});
