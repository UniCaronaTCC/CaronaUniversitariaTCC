import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';

import { Avaliacao } from './avaliacao.entity';
import { ReputacoesService } from './reputacoes.service';

@Module({
  imports: [TypeOrmModule.forFeature([Avaliacao])],
  providers: [ReputacoesService],
  exports: [ReputacoesService],
})
export class ReputacoesModule {}
