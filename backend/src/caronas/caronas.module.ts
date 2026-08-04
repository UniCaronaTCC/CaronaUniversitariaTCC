import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';

import { AuthModule } from '../auth/auth.module';
// Importa o módulo de autenticação para usar o JwtAuthGuard

import { Carona } from './carona.entity';
import { CaronasController } from './caronas.controller';
import { CaronasService } from './caronas.service';

@Module({
  imports: [
    TypeOrmModule.forFeature([Carona]),
    // Permite usar o repositório da entidade Carona

    AuthModule,
    // Permite proteger rotas de caronas com JWT
  ],

  controllers: [CaronasController],

  providers: [CaronasService],

  exports: [CaronasService],
})
export class CaronasModule {}
