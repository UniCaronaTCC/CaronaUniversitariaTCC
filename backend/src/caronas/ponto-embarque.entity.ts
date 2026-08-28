import {
  Column,
  Entity,
  JoinColumn,
  ManyToOne,
  PrimaryGeneratedColumn,
} from 'typeorm';

import { numeroDecimalTransformer } from '../database/numero-decimal.transformer';
import { Carona } from './carona.entity';

@Entity('pontos_embarque')
export class PontoEmbarque {
  @PrimaryGeneratedColumn({ name: 'id_ponto_embarque' })
  idPontoEmbarque!: number;

  @Column({
    type: 'varchar',
    length: 100,
    nullable: true,
  })
  nome: string | null = null;

  @Column({
    type: 'varchar',
    length: 255,
  })
  endereco!: string;

  @Column({
    type: 'decimal',
    precision: 10,
    scale: 8,
    transformer: numeroDecimalTransformer,
  })
  latitude!: number;

  @Column({
    type: 'decimal',
    precision: 11,
    scale: 8,
    transformer: numeroDecimalTransformer,
  })
  longitude!: number;

  @Column({
    type: 'int',
    default: 1,
  })
  ordem: number = 1;

  @ManyToOne(
    () => Carona,
    (carona) => carona.pontosEmbarque,
    {
      onDelete: 'CASCADE',
    },
  )
  @JoinColumn({ name: 'id_carona' })
  carona!: Carona;
}
