import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { TypeOrmModule } from '@nestjs/typeorm';

import { AuthModule } from '../auth/auth.module';
import { Solicitacao } from '../solicitacoes/solicitacao.entity';
import { AbacatePayWebhookController } from './abacatepay-webhook.controller';
import { AbacatePayWebhookService } from './abacatepay-webhook.service';
import { AbacatePayService } from './abacatepay.service';
import { PagamentoEventoWebhook } from './pagamento-evento-webhook.entity';
import { Pagamento } from './pagamento.entity';
import { PagamentosController } from './pagamentos.controller';
import { PagamentosService } from './pagamentos.service';

@Module({
  imports: [
    ConfigModule,
    TypeOrmModule.forFeature([Pagamento, PagamentoEventoWebhook, Solicitacao]),
    AuthModule,
  ],
  controllers: [PagamentosController, AbacatePayWebhookController],
  providers: [AbacatePayService, AbacatePayWebhookService, PagamentosService],
  exports: [AbacatePayService, PagamentosService],
})
export class PagamentosModule {}
