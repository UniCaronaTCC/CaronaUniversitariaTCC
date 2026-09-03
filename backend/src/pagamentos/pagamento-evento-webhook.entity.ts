import {
  Column,
  CreateDateColumn,
  Entity,
  Index,
  JoinColumn,
  ManyToOne,
  PrimaryColumn,
} from 'typeorm';

import { Pagamento } from './pagamento.entity';

@Entity('pagamentos_eventos_webhook')
@Index('idx_pagamentos_eventos_webhook_pagamento', [
  'pagamento',
  'processadoEm',
])
export class PagamentoEventoWebhook {
  @PrimaryColumn({ name: 'id_evento', type: 'varchar', length: 100 })
  idEvento!: string;

  @ManyToOne(() => Pagamento, { onDelete: 'RESTRICT' })
  @JoinColumn({ name: 'id_pagamento' })
  pagamento!: Pagamento;

  @Column({ type: 'varchar', length: 50 })
  tipo!: string;

  @CreateDateColumn({ name: 'processado_em', type: 'timestamptz' })
  processadoEm!: Date;
}
