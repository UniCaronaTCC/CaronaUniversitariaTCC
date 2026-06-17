import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';

import { Carona } from './carona.entity';
import { CaronasController } from './caronas.controller';
import { CaronasService } from './caronas.service';

@Module({
  imports: [
    TypeOrmModule.forFeature([Carona]),
  ],
  controllers: [CaronasController],
  providers: [CaronasService],
  exports: [CaronasService],
})
export class CaronasModule {}