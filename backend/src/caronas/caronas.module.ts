import { ProgressoCaronaService } from './progresso-carona.service';
import { ProgressoCaronaController } from './progresso-carona.controller';
import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';

import { AuthModule } from '../auth/auth.module';
// Importa o módulo de autenticação para usar o JwtAuthGuard

import { Carona } from './carona.entity';
import { CaronasController } from './caronas.controller';
import { CaronasService } from './caronas.service';
import { PontoEmbarque } from './ponto-embarque.entity';
import { PosicaoAtualCarona } from './posicao-atual-carona.entity';
import { Solicitacao } from '../solicitacoes/solicitacao.entity';
import { RecorrenciaCarona } from './recorrencia.entity';
import { PontoEmbarqueRecorrencia } from './ponto-embarque-recorrencia.entity';
import { RecorrenciasService } from './recorrencias.service';
import { RecorrenciasController } from './recorrencias.controller';
import { EncerramentoCorridasService } from './encerramento-corridas.service';
import { ExpiracaoSolicitacoesService } from '../solicitacoes/expiracao-solicitacoes.service';
import { PagamentosModule } from '../pagamentos/pagamentos.module';

@Module({
  imports: [
    TypeOrmModule.forFeature([
      Carona,
      PontoEmbarque,
      PosicaoAtualCarona,
      Solicitacao,
      RecorrenciaCarona,
      PontoEmbarqueRecorrencia,
    ]),
    // Permite usar os repositórios de Carona e PontoEmbarque

    AuthModule,
    PagamentosModule,
    // Permite proteger rotas de caronas com JWT
  ],

  controllers: [
    CaronasController,
    RecorrenciasController,
    ProgressoCaronaController,
  ],

  providers: [
    CaronasService,
    RecorrenciasService,
    ProgressoCaronaService,
    EncerramentoCorridasService,
    ExpiracaoSolicitacoesService,
  ],

  exports: [CaronasService],
})
export class CaronasModule {}
