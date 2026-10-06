import {
  Column,
  CreateDateColumn,
  Entity,
  OneToOne,
  PrimaryGeneratedColumn,
} from 'typeorm';

import { Veiculo } from './veiculo.entity';

export type StatusVerificacaoCnh =
  | 'NAO_ENVIADA'
  | 'EM_ANALISE'
  | 'APROVADA'
  | 'RECUSADA';

@Entity('usuarios')
export class User {
  @PrimaryGeneratedColumn({ name: 'id_usuario' })
  idUsuario: number;

  @Column({
    name: 'auth_id',
    type: 'uuid',
    nullable: true,
    unique: true,
  })
  authId: string | null = null;

  @Column({ length: 100 })
  nome: string;

  @Column({ length: 100, unique: true })
  email: string;

  @Column({
    name: 'id_instituicao',
    type: 'int',
    nullable: true,
  })
  idInstituicao: number | null = null;

  @Column({
    type: 'varchar',
    length: 255,
    nullable: true,
  })
  instituicao: string | null = null;

  @Column({
    type: 'varchar',
    length: 150,
    nullable: true,
  })
  campus: string | null = null;

  @Column({
    name: 'foto_perfil',
    type: 'varchar',
    length: 500,
    nullable: true,
  })
  fotoPerfil: string | null = null;

  @Column({
    name: 'tipo_perfil',
    type: 'varchar',
    length: 20,
    default: 'PASSAGEIRO',
  })
  tipoPerfil: string = 'PASSAGEIRO';

  @Column({
    name: 'tipo_perfil_solicitado',
    type: 'varchar',
    length: 20,
    nullable: true,
  })
  tipoPerfilSolicitado: string | null = null;

  @Column({
    name: 'status_verificacao',
    type: 'varchar',
    length: 20,
    default: 'NAO_ENVIADO',
  })
  statusVerificacao: string = 'NAO_ENVIADO';

  @Column({ type: 'varchar', length: 11, nullable: true, select: false })
  cpf: string | null;

  @Column({
    name: 'status_verificacao_cnh',
    type: 'varchar',
    length: 20,
    default: 'NAO_ENVIADA',
  })
  statusVerificacaoCnh: StatusVerificacaoCnh = 'NAO_ENVIADA';

  @Column({ name: 'cnh_categoria', type: 'varchar', length: 5, nullable: true })
  cnhCategoria: string | null = null;

  @Column({ name: 'cnh_validade', type: 'date', nullable: true })
  cnhValidade: string | null = null;

  @Column({
    name: 'cnh_registro_final',
    type: 'varchar',
    length: 4,
    nullable: true,
    select: false,
  })
  cnhRegistroFinal: string | null;

  @Column({ name: 'cnh_verificada_em', type: 'timestamptz', nullable: true })
  cnhVerificadaEm: Date | null = null;

  @Column({
    name: 'privacidade_aceita_em',
    type: 'timestamptz',
    nullable: true,
  })
  privacidadeAceitaEm: Date | null = null;

  @OneToOne(() => Veiculo, (veiculo) => veiculo.usuario)
  veiculo: Veiculo | null = null;

  @Column({
    name: 'documento_verificacao',
    type: 'varchar',
    length: 255,
    nullable: true,
    select: false,
  })
  documentoVerificacao: string | null = null;

  @CreateDateColumn({ name: 'criado_em', type: 'timestamptz' })
  criadoEm: Date;
}
