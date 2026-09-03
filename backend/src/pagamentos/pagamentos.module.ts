import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { TypeOrmModule } from '@nestjs/typeorm';

import { AuthModule } from '../auth/auth.module';
import { Solicitacao } from '../solicitacoes/solicitacao.entity';
import { AbacatePayService } from './abacatepay.service';
import { Pagamento } from './pagamento.entity';
import { PagamentosController } from './pagamentos.controller';
import { PagamentosService } from './pagamentos.service';

@Module({
  imports: [
    ConfigModule,
    TypeOrmModule.forFeature([Pagamento, Solicitacao]),
    AuthModule,
  ],
  controllers: [PagamentosController],
  providers: [AbacatePayService, PagamentosService],
  exports: [AbacatePayService, PagamentosService],
})
export class PagamentosModule {}
