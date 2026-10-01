import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';

import { AuthModule } from '../auth/auth.module';
import { AvaliacoesModule } from '../avaliacoes/avaliacoes.module';
import { Carona } from '../caronas/carona.entity';
import { CaronasModule } from '../caronas/caronas.module';
import { PontoEmbarque } from '../caronas/ponto-embarque.entity';
import { Pagamento } from '../pagamentos/pagamento.entity';
import { PagamentosModule } from '../pagamentos/pagamentos.module';

import { ExpiracaoSolicitacoesService } from './expiracao-solicitacoes.service';
import { Solicitacao } from './solicitacao.entity';
import { SolicitacoesController } from './solicitacoes.controller';
import { SolicitacoesService } from './solicitacoes.service';

@Module({
  imports: [
    TypeOrmModule.forFeature([Solicitacao, Carona, PontoEmbarque, Pagamento]),
    AuthModule,
    AvaliacoesModule,
    CaronasModule,
    PagamentosModule,
  ],
  controllers: [SolicitacoesController],
  providers: [SolicitacoesService, ExpiracaoSolicitacoesService],
  exports: [SolicitacoesService],
})
export class SolicitacoesModule {}
