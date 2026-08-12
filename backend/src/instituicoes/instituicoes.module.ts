import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';

import { Instituicao } from './instituicao.entity';
import { InstituicoesController } from './instituicoes.controller';
import { InstituicoesService } from './instituicoes.service';

@Module({
  imports: [TypeOrmModule.forFeature([Instituicao])],
  controllers: [InstituicoesController],
  providers: [InstituicoesService],
  exports: [InstituicoesService],
})
export class InstituicoesModule {}
