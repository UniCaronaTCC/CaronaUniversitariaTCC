import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';

import { InstituicoesModule } from '../instituicoes/instituicoes.module';
import { FotoPerfilService } from './foto-perfil.service';
import { User } from './user.entity';
import { Veiculo } from './veiculo.entity';
import { UsersService } from './users.service';

@Module({
  imports: [TypeOrmModule.forFeature([User, Veiculo]), InstituicoesModule],
  providers: [UsersService, FotoPerfilService],
  exports: [UsersService, FotoPerfilService],
})
export class UsersModule {}
