import {
  Column,
  Check,
  CreateDateColumn,
  Entity,
  Index,
  JoinColumn,
  ManyToOne,
  PrimaryGeneratedColumn,
} from 'typeorm';

import { Solicitacao } from '../solicitacoes/solicitacao.entity';
import { User } from '../users/user.entity';

@Entity('avaliacoes')
@Check('chk_avaliacoes_nota', 'nota >= 1 AND nota <= 5')
@Index('uq_avaliacao_solicitacao_avaliador', ['solicitacao', 'avaliador'], {
  unique: true,
})
export class Avaliacao {
  @PrimaryGeneratedColumn({ name: 'id_avaliacao' })
  idAvaliacao!: number;

  @ManyToOne(() => Solicitacao, { onDelete: 'RESTRICT' })
  @JoinColumn({ name: 'id_solicitacao' })
  solicitacao!: Solicitacao;

  @ManyToOne(() => User, { onDelete: 'RESTRICT' })
  @JoinColumn({ name: 'id_avaliador' })
  avaliador!: User;

  @ManyToOne(() => User, { onDelete: 'RESTRICT' })
  @JoinColumn({ name: 'id_avaliado' })
  avaliado!: User;

  @Column({ type: 'smallint' })
  nota!: number;

  @Column({ type: 'varchar', length: 500, nullable: true })
  comentario: string | null = null;

  @CreateDateColumn({ name: 'criado_em', type: 'timestamptz' })
  criadoEm!: Date;
}
