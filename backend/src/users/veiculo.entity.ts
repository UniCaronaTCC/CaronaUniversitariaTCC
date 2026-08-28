import {
  Column,
  CreateDateColumn,
  Entity,
  JoinColumn,
  OneToOne,
  PrimaryGeneratedColumn,
} from 'typeorm';

import { User } from './user.entity';

@Entity('veiculos')
export class Veiculo {
  @PrimaryGeneratedColumn({ name: 'id_veiculo' })
  idVeiculo: number;

  @Column({ length: 100 })
  modelo: string;

  @Column({ length: 50 })
  cor: string;

  @Column({ length: 10, unique: true })
  placa: string;

  @OneToOne(() => User)
  @JoinColumn({ name: 'id_usuario' })
  usuario: User;

  @CreateDateColumn({ name: 'criado_em', type: 'timestamptz' })
  criadoEm: Date;
}
