import {
  Column,
  CreateDateColumn,
  Entity,
  Index,
  PrimaryGeneratedColumn,
} from 'typeorm';

@Entity('notificacoes')
@Index('uq_notificacoes_usuario_evento', ['idUsuario', 'chaveEvento'], {
  unique: true,
})
export class Notificacao {
  @PrimaryGeneratedColumn({ name: 'id_notificacao' })
  id!: number;

  @Column({ name: 'id_usuario', type: 'int' })
  idUsuario!: number;

  @Column({ length: 30 })
  tipo!: string;

  @Column({ length: 160 })
  titulo!: string;

  @Column({ length: 600 })
  descricao!: string;

  @Column({ name: 'chave_evento', length: 180, select: false })
  chaveEvento!: string;

  @Column({ type: 'jsonb', default: {} })
  referencias!: Record<string, unknown>;

  @CreateDateColumn({ name: 'criado_em', type: 'timestamptz' })
  criadoEm!: Date;

  @Column({ name: 'lida_em', type: 'timestamptz', nullable: true })
  lidaEm: Date | null = null;
}
