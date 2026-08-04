import {
  Column,
  CreateDateColumn,
  Entity,
  JoinColumn,
  ManyToOne,
  PrimaryGeneratedColumn,
} from 'typeorm';

import { User } from '../users/user.entity';

@Entity('caronas')
export class Carona {
  @PrimaryGeneratedColumn({ name: 'id_carona' })
  idCarona!: number;

  @Column({ length: 100 })
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
  })
  origemLatitude: number | null = null;

  @Column({
    name: 'origem_longitude',
    type: 'decimal',
    precision: 11,
    scale: 8,
    nullable: true,
  })
  origemLongitude: number | null = null;

  @Column({ length: 100 })
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
  })
  destinoLatitude: number | null = null;

  @Column({
    name: 'destino_longitude',
    type: 'decimal',
    precision: 11,
    scale: 8,
    nullable: true,
  })
  destinoLongitude: number | null = null;

  @Column({ name: 'data_inicio', type: 'date' })
  dataInicio!: string;

  @Column({ name: 'data_fim', type: 'date', nullable: true })
  dataFim: string | null = null;

  @Column({ type: 'time' })
  horario!: string;

  @Column({ type: 'int', unsigned: true })
  vagas!: number;

  @Column({ type: 'decimal', precision: 10, scale: 2 })
  valor!: number;

  @Column({ default: false })
  recorrente: boolean = false;

  @Column({ name: 'dias_semana', type: 'json', nullable: true })
  diasSemana: string[] | null = null;

  @Column({ type: 'text', nullable: true })
  observacoes: string | null = null;

  @Column({ length: 30, default: 'ATIVA' })
  status: string = 'ATIVA';

  @ManyToOne(() => User)
  @JoinColumn({ name: 'id_usuario' })
  usuario!: User;

  @CreateDateColumn({ name: 'criado_em' })
  criadoEm!: Date;
}
