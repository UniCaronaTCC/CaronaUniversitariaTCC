import {
  Column,
  Entity,
  JoinColumn,
  OneToOne,
  PrimaryColumn,
  UpdateDateColumn,
} from 'typeorm';

import { numeroDecimalTransformer } from '../database/numero-decimal.transformer';
import { Carona } from './carona.entity';

@Entity('posicao_atual_carona')
export class PosicaoAtualCarona {
  @PrimaryColumn({ name: 'id_carona', type: 'int' })
  idCarona!: number;

  @OneToOne(() => Carona, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'id_carona' })
  carona!: Carona;

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
    type: 'decimal',
    precision: 6,
    scale: 2,
    nullable: true,
    transformer: numeroDecimalTransformer,
  })
  direcao: number | null = null;

  @Column({
    type: 'decimal',
    precision: 8,
    scale: 2,
    transformer: numeroDecimalTransformer,
  })
  precisao!: number;

  @UpdateDateColumn({ name: 'atualizado_em', type: 'timestamptz' })
  atualizadoEm!: Date;
}
