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

  @Column({ length: 100 })
  destino!: string;

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