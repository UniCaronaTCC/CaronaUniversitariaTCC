import {
  Column,
  CreateDateColumn,
  Entity,
  Index,
  JoinColumn,
  ManyToOne,
  PrimaryGeneratedColumn,
} from 'typeorm';

import { User } from '../users/user.entity';
import { Conversa } from './conversa.entity';

@Entity('mensagens')
@Index('idx_mensagens_conversa_criado_em', ['conversa', 'criadoEm'])
export class Mensagem {
  @PrimaryGeneratedColumn({ name: 'id_mensagem' })
  idMensagem!: number;

  @ManyToOne(() => Conversa, (conversa) => conversa.mensagens, {
    onDelete: 'RESTRICT',
  })
  @JoinColumn({ name: 'id_conversa' })
  conversa!: Conversa;

  @ManyToOne(() => User, { onDelete: 'RESTRICT' })
  @JoinColumn({ name: 'id_remetente' })
  remetente!: User;

  @Column({ type: 'varchar', length: 1000 })
  conteudo!: string;

  @CreateDateColumn({ name: 'criado_em', type: 'timestamptz' })
  criadoEm!: Date;
}
