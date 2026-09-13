import {
  Column,
  CreateDateColumn,
  Entity,
  Index,
  JoinColumn,
  ManyToOne,
  PrimaryGeneratedColumn,
  UpdateDateColumn,
} from 'typeorm';

import { numeroInteiroGrandeTransformer } from '../database/numero-inteiro-grande.transformer';
import { Solicitacao } from '../solicitacoes/solicitacao.entity';
import type { StatusPix } from './abacatepay.types';

export type StatusCriacaoPagamento =
  | 'PREPARADA'
  | 'CONFIRMADA'
  | 'INCERTA'
  | 'FALHOU';

@Entity('pagamentos')
@Index('uq_pagamentos_referencia', ['referencia'], { unique: true })
@Index('uq_pagamentos_provedor_id', ['provedor', 'modoTeste', 'idProvedor'], {
  unique: true,
})
@Index('idx_pagamentos_solicitacao_criado_em', ['solicitacao', 'criadoEm'])
export class Pagamento {
  @PrimaryGeneratedColumn({ name: 'id_pagamento' })
  idPagamento!: number;

  @ManyToOne(() => Solicitacao, { onDelete: 'RESTRICT' })
  @JoinColumn({ name: 'id_solicitacao' })
  solicitacao!: Solicitacao;

  @Column({ type: 'uuid' })
  referencia!: string;

  @Column({ type: 'varchar', length: 30, default: 'ABACATEPAY' })
  provedor = 'ABACATEPAY' as const;

  @Column({ name: 'modo_teste', default: true })
  modoTeste: boolean = true;

  @Column({ type: 'varchar', length: 10, default: 'PIX' })
  metodo = 'PIX' as const;

  @Column({
    name: 'valor_centavos',
    type: 'bigint',
    transformer: numeroInteiroGrandeTransformer,
  })
  valorCentavos!: number;

  @Column({
    name: 'status_criacao',
    type: 'varchar',
    length: 20,
    default: 'PREPARADA',
  })
  statusCriacao: StatusCriacaoPagamento = 'PREPARADA';

  @Column({ name: 'id_provedor', type: 'varchar', length: 100, nullable: true })
  idProvedor: string | null = null;

  @Column({
    name: 'status_provedor',
    type: 'varchar',
    length: 30,
    nullable: true,
  })
  statusProvedor: StatusPix | null = null;

  @Column({ name: 'pix_copia_e_cola', type: 'text', nullable: true })
  pixCopiaECola: string | null = null;

  @Column({ name: 'qr_code_base64', type: 'text', nullable: true })
  qrCodeBase64: string | null = null;

  @Column({ name: 'expira_em', type: 'timestamptz', nullable: true })
  expiraEm: Date | null = null;

  @CreateDateColumn({ name: 'criado_em', type: 'timestamptz' })
  criadoEm!: Date;

  @UpdateDateColumn({ name: 'atualizado_em', type: 'timestamptz' })
  atualizadoEm!: Date;
}
