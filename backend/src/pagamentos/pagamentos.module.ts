import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';

import { AbacatePayService } from './abacatepay.service';

@Module({
  imports: [ConfigModule],
  providers: [AbacatePayService],
  exports: [AbacatePayService],
})
export class PagamentosModule {}
