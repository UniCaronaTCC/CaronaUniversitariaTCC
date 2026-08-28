import {
  Column,
  CreateDateColumn,
  Entity,
  JoinColumn,
  ManyToOne,
  OneToMany,
  PrimaryGeneratedColumn,
} from 'typeorm';

import { numeroDecimalTransformer } from '../database/numero-decimal.transformer';
import { User } from '../users/user.entity';
import { PontoEmbarque } from './ponto-embarque.entity';

@Entity('caronas')
export class Carona {
  @PrimaryGeneratedColumn({ name: 'id_carona' })
  idCarona!: number;

  @Column({ length: 255 })
  origem!: string;

  @Column({
    name: 'origem_cidade',
    type: 'varchar',
    length: 100,
    nullable: true,
  })
  origemCidade: string | null = null;

  @Column({
    name: 'origem_latitude',
    type: 'decimal',
    precision: 10,
    scale: 8,
    nullable: true,
    transformer: numeroDecimalTransformer,
  })
  origemLatitude: number | null = null;

  @Column({
    name: 'origem_longitude',
    type: 'decimal',
    precision: 11,
    scale: 8,
    nullable: true,
    transformer: numeroDecimalTransformer,
  })
  origemLongitude: number | null = null;

  @Column({ length: 255 })
  destino!: string;

  @Column({
    name: 'destino_cidade',
    type: 'varchar',
    length: 100,
    nullable: true,
  })
  destinoCidade: string | null = null;

  @Column({
    name: 'destino_latitude',
    type: 'decimal',
    precision: 10,
    scale: 8,
    nullable: true,
    transformer: numeroDecimalTransformer,
  })
  destinoLatitude: number | null = null;

  @Column({
    name: 'destino_longitude',
    type: 'decimal',
    precision: 11,
    scale: 8,
    nullable: true,
    transformer: numeroDecimalTransformer,
  })
  destinoLongitude: number | null = null;

  @Column({ name: 'data_inicio', type: 'date' })
  dataInicio!: string;

  @Column({ name: 'data_fim', type: 'date', nullable: true })
  dataFim: string | null = null;

  @Column({ type: 'time' })
  horario!: string;

  @Column({ type: 'int' })
  vagas!: number;

  @Column({
    type: 'decimal',
    precision: 10,
    scale: 2,
    transformer: numeroDecimalTransformer,
  })
  valor!: number;

  @Column({ default: false })
  recorrente: boolean = false;

  @Column({ name: 'dias_semana', type: 'jsonb', nullable: true })
  diasSemana: string[] | null = null;

  @Column({ type: 'text', nullable: true })
  observacoes: string | null = null;

  @Column({ length: 30, default: 'ATIVA' })
  status: string = 'ATIVA';

  @ManyToOne(() => User)
  @JoinColumn({ name: 'id_usuario' })
  usuario!: User;

  @OneToMany(
    () => PontoEmbarque,
    (ponto) => ponto.carona,
    {
      cascade: true,
    },
  )
  pontosEmbarque!: PontoEmbarque[];

  @CreateDateColumn({ name: 'criado_em', type: 'timestamptz' })
  criadoEm!: Date;
}
