import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';

import { Avaliacao } from './avaliacao.entity';

@Module({
  imports: [TypeOrmModule.forFeature([Avaliacao])],
})
export class AvaliacoesModule {}
