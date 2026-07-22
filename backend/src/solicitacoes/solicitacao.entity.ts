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
import { User } from '../users/user.entity';

@Entity('solicitacoes')
@Index('uq_solicitacao_carona_passageiro', ['carona', 'passageiro'], {
  unique: true,
})
export class Solicitacao {
  @PrimaryGeneratedColumn({ name: 'id_solicitacao' })
  idSolicitacao!: number;

  @ManyToOne(() => Carona, { onDelete: 'RESTRICT' })
  @JoinColumn({ name: 'id_carona' })
  carona!: Carona;

  @ManyToOne(() => User, { onDelete: 'RESTRICT' })
  @JoinColumn({ name: 'id_passageiro' })
  passageiro!: User;

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
