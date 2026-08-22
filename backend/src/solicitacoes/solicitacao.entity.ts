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

import { Carona } from '../caronas/carona.entity';
import { PontoEmbarque } from '../caronas/ponto-embarque.entity';
import { User } from '../users/user.entity';

@Entity('solicitacoes')
@Index(
  'uq_solicitacao_carona_passageiro',
  ['carona', 'passageiro'],
  {
    unique: true,
  },
)
export class Solicitacao {
  avaliada = false;
  podeAvaliar = false;

  @PrimaryGeneratedColumn({ name: 'id_solicitacao' })
  idSolicitacao!: number;

  @ManyToOne(() => Carona, { onDelete: 'RESTRICT' })
  @JoinColumn({ name: 'id_carona' })
  carona!: Carona;

  @ManyToOne(() => User, { onDelete: 'RESTRICT' })
  @JoinColumn({ name: 'id_passageiro' })
  passageiro!: User;

  // Quando o passageiro escolhe um ponto que já existe na carona.
  @ManyToOne(() => PontoEmbarque, {
    nullable: true,
    onDelete: 'SET NULL',
  })
  @JoinColumn({ name: 'id_ponto_embarque' })
  pontoEmbarque: PontoEmbarque | null = null;

  // Diferencia ponto já existente de um novo ponto solicitado.
  @Column({
    name: 'tipo_ponto_embarque',
    type: 'varchar',
    length: 30,
    default: 'EXISTENTE',
  })
  tipoPontoEmbarque: string = 'EXISTENTE';

  // Também guarda os dados do local escolhido ou solicitado.
  @Column({ name: 'local_embarque', length: 255 })
  localEmbarque!: string;

  @Column({
    name: 'embarque_latitude',
    type: 'decimal',
    precision: 10,
    scale: 8,
  })
  embarqueLatitude!: number;

  @Column({
    name: 'embarque_longitude',
    type: 'decimal',
    precision: 11,
    scale: 8,
  })
  embarqueLongitude!: number;

  @Column({ length: 30, default: 'PENDENTE' })
  status: string = 'PENDENTE';

  @CreateDateColumn({ name: 'criado_em' })
  criadoEm!: Date;

  @UpdateDateColumn({ name: 'atualizado_em' })
  atualizadoEm!: Date;
}