import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';

import { InstituicoesModule } from '../instituicoes/instituicoes.module';
import { FotoPerfilService } from './foto-perfil.service';
import { LeituraCnhService } from './leitura-cnh.service';
import { User } from './user.entity';
import { Veiculo } from './veiculo.entity';
import { UsersService } from './users.service';
import { VerificacaoCnhService } from './verificacao-cnh.service';

@Module({
  imports: [TypeOrmModule.forFeature([User, Veiculo]), InstituicoesModule],
  providers: [
    UsersService,
    FotoPerfilService,
    LeituraCnhService,
    VerificacaoCnhService,
  ],
  exports: [UsersService, FotoPerfilService, VerificacaoCnhService],
})
export class UsersModule {}
