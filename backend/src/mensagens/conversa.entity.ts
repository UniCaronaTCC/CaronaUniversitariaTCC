import {
  CreateDateColumn,
  Entity,
  Index,
  JoinColumn,
  ManyToOne,
  OneToMany,
  PrimaryGeneratedColumn,
} from 'typeorm';

import { Solicitacao } from '../solicitacoes/solicitacao.entity';
import { Mensagem } from './mensagem.entity';

@Entity('conversas')
@Index('uq_conversas_solicitacao', ['solicitacao'], { unique: true })
export class Conversa {
  @PrimaryGeneratedColumn({ name: 'id_conversa' })
  idConversa!: number;

  @ManyToOne(() => Solicitacao, { onDelete: 'RESTRICT' })
  @JoinColumn({ name: 'id_solicitacao' })
  solicitacao!: Solicitacao;

  @OneToMany(() => Mensagem, (mensagem) => mensagem.conversa)
  mensagens!: Mensagem[];

  @CreateDateColumn({ name: 'criado_em', type: 'timestamptz' })
  criadoEm!: Date;
}
