import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';

import { InstituicaoCampus } from './instituicao-campus.entity';
import { Instituicao } from './instituicao.entity';
import { InstituicoesController } from './instituicoes.controller';
import { InstituicoesService } from './instituicoes.service';

@Module({
  imports: [TypeOrmModule.forFeature([Instituicao, InstituicaoCampus])],
  controllers: [InstituicoesController],
  providers: [InstituicoesService],
  exports: [InstituicoesService],
})
export class InstituicoesModule {}
