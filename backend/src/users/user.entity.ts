import {
  Column,
  CreateDateColumn,
  Entity,
  PrimaryGeneratedColumn,
} from 'typeorm';

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
