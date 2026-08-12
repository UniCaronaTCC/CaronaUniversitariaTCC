import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';

import { AuthModule } from '../auth/auth.module';
import { CaronasModule } from '../caronas/caronas.module';
import { Solicitacao } from '../solicitacoes/solicitacao.entity';
import { UsersModule } from '../users/users.module';
import { Avaliacao } from './avaliacao.entity';
import { AvaliacoesController } from './avaliacoes.controller';
import { AvaliacoesService } from './avaliacoes.service';

@Module({
  imports: [
    TypeOrmModule.forFeature([Avaliacao, Solicitacao]),
    AuthModule,
    CaronasModule,
    UsersModule,
  ],
  controllers: [AvaliacoesController],
  providers: [AvaliacoesService],
  exports: [AvaliacoesService],
})
export class AvaliacoesModule {}
