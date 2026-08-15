import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';

import { AuthModule } from '../auth/auth.module';
// Importa o módulo de autenticação para usar o JwtAuthGuard

import { Carona } from './carona.entity';
import { CaronasController } from './caronas.controller';
import { CaronasService } from './caronas.service';
import { PontoEmbarque } from './ponto-embarque.entity';

@Module({
  imports: [
    TypeOrmModule.forFeature([
      Carona,
      PontoEmbarque,
    ]),
    // Permite usar os repositórios de Carona e PontoEmbarque

    AuthModule,
    // Permite proteger rotas de caronas com JWT
  ],

  controllers: [CaronasController],

  providers: [CaronasService],

  exports: [CaronasService],
})
export class CaronasModule {}