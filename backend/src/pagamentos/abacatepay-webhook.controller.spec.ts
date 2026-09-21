import { BadRequestException, RawBodyRequest } from '@nestjs/common';
import { Request } from 'express';

import { AbacatePayWebhookController } from './abacatepay-webhook.controller';
import { AbacatePayWebhookService } from './abacatepay-webhook.service';

describe('AbacatePayWebhookController', () => {
  let controller: AbacatePayWebhookController;
  let webhookService: { processar: jest.Mock };

  beforeEach(() => {
    webhookService = {
      processar: jest.fn().mockResolvedValue({
        processado: true,
        duplicado: false,
      }),
    };
    controller = new AbacatePayWebhookController(
      webhookService as unknown as AbacatePayWebhookService,
    );
  });

  it('repassa secret, assinatura e corpo bruto ao service', async () => {
    const corpo = { event: 'transparent.completed' };
    const corpoBruto = Buffer.from(JSON.stringify(corpo));
    const request = { rawBody: corpoBruto } as RawBodyRequest<Request>;

    await expect(
      controller.receber('secret', 'assinatura', request, corpo),
    ).resolves.toEqual({ processado: true, duplicado: false });
    expect(webhookService.processar).toHaveBeenCalledWith({
      secretRecebido: 'secret',
      assinaturaRecebida: 'assinatura',
      corpoBruto,
      corpo,
    });
  });

  it('recusa requisicao sem o corpo bruto usado no HMAC', () => {
    const request = {} as RawBodyRequest<Request>;

    expect(() =>
      controller.receber('secret', 'assinatura', request, {}),
    ).toThrow(BadRequestException);
    expect(webhookService.processar).not.toHaveBeenCalled();
  });
});
