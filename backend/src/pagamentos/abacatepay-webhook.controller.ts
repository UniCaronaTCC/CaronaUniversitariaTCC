import {
  BadRequestException,
  Body,
  Controller,
  Headers,
  HttpCode,
  Post,
  Query,
  Req,
} from '@nestjs/common';
import type { RawBodyRequest } from '@nestjs/common';
import type { Request } from 'express';

import { AbacatePayWebhookService } from './abacatepay-webhook.service';

@Controller('pagamentos/webhooks')
export class AbacatePayWebhookController {
  constructor(
    private readonly abacatePayWebhookService: AbacatePayWebhookService,
  ) {}

  @Post('abacatepay')
  @HttpCode(200)
  receber(
    @Query('webhookSecret') webhookSecret: string | undefined,
    @Headers('x-webhook-signature') assinatura: string | undefined,
    @Req() request: RawBodyRequest<Request>,
    @Body() corpo: unknown,
  ) {
    if (!request.rawBody) {
      throw new BadRequestException('Corpo bruto do webhook indisponivel');
    }

    return this.abacatePayWebhookService.processar({
      secretRecebido: webhookSecret,
      assinaturaRecebida: assinatura,
      corpoBruto: request.rawBody,
      corpo,
    });
  }
}
