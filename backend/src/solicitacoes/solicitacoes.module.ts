import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';

import { AuthModule } from '../auth/auth.module';
import { AvaliacoesModule } from '../avaliacoes/avaliacoes.module';
import { Carona } from '../caronas/carona.entity';
import { CaronasModule } from '../caronas/caronas.module';
import { PontoEmbarque } from '../caronas/ponto-embarque.entity';

import { Solicitacao } from './solicitacao.entity';
import { SolicitacoesController } from './solicitacoes.controller';
import { SolicitacoesService } from './solicitacoes.service';

@Module({
  imports: [
    TypeOrmModule.forFeature([
      Solicitacao,
      Carona,
      PontoEmbarque,
    ]),
    AuthModule,
    AvaliacoesModule,
    CaronasModule,
  ],
  controllers: [SolicitacoesController],
  providers: [SolicitacoesService],
  exports: [SolicitacoesService],
})
export class SolicitacoesModule {}