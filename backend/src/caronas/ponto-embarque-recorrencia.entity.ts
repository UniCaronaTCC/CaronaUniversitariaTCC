import {
  Column,
  Entity,
  JoinColumn,
  ManyToOne,
  PrimaryGeneratedColumn,
} from 'typeorm';
import { numeroDecimalTransformer } from '../database/numero-decimal.transformer';
import { RecorrenciaCarona } from './recorrencia.entity';

@Entity('pontos_embarque_recorrencia')
export class PontoEmbarqueRecorrencia {
  @PrimaryGeneratedColumn({ name: 'id_ponto_embarque_recorrencia' })
  idPontoEmbarqueRecorrencia!: number;

  @Column({ name: 'id_recorrencia', type: 'int' })
  idRecorrencia!: number;

  @Column({ type: 'varchar', length: 100, nullable: true })
  nome: string | null = null;

  @Column({ length: 255 })
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

  @Column({ type: 'int' })
  ordem!: number;

  @ManyToOne(() => RecorrenciaCarona, (modelo) => modelo.pontosEmbarque, {
    onDelete: 'CASCADE',
  })
  @JoinColumn({ name: 'id_recorrencia' })
  recorrencia!: RecorrenciaCarona;
}
