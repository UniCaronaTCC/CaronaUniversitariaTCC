import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';

import { AuthModule } from '../auth/auth.module';
import { CaronasModule } from '../caronas/caronas.module';
import { Solicitacao } from '../solicitacoes/solicitacao.entity';
import { Conversa } from './conversa.entity';
import { Mensagem } from './mensagem.entity';
import { MensagensController } from './mensagens.controller';
import { MensagensService } from './mensagens.service';

@Module({
  imports: [
    TypeOrmModule.forFeature([Conversa, Mensagem, Solicitacao]),
    AuthModule,
    CaronasModule,
  ],
  controllers: [MensagensController],
  providers: [MensagensService],
})
export class MensagensModule {}
