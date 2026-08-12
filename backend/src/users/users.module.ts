import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';

import { InstituicoesModule } from '../instituicoes/instituicoes.module';
import { User } from './user.entity';
import { Veiculo } from './veiculo.entity';
import { UsersService } from './users.service';

@Module({
  imports: [TypeOrmModule.forFeature([User, Veiculo]), InstituicoesModule],
  providers: [UsersService],
  exports: [UsersService],
})
export class UsersModule {}
