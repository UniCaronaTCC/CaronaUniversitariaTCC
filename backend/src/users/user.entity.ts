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

  // =========================
  // VERIFICAÇÃO DE E-MAIL
  // =========================

  @Column({
    name: 'email_verificado',
    type: 'boolean',
    default: false,
  })
  emailVerificado: boolean = false;

  @Column({
    name: 'codigo_verificacao_email',
    type: 'varchar',
    length: 255,
    nullable: true,
    select: false,
  })
  codigoVerificacaoEmail: string | null = null;

  @Column({
    name: 'codigo_verificacao_email_expira_em',
    type: 'timestamptz',
    nullable: true,
    select: false,
  })
  codigoVerificacaoEmailExpiraEm: Date | null = null;

  @Column({
    name: 'codigo_verificacao_email_enviado_em',
    type: 'timestamptz',
    nullable: true,
    select: false,
  })
  codigoVerificacaoEmailEnviadoEm: Date | null = null;

  @Column({
    name: 'codigo_redefinicao_senha',
    type: 'varchar',
    length: 255,
    nullable: true,
    select: false,
  })
  codigoRedefinicaoSenha: string | null = null;

  @Column({
    name: 'codigo_redefinicao_senha_expira_em',
    type: 'timestamptz',
    nullable: true,
    select: false,
  })
  codigoRedefinicaoSenhaExpiraEm: Date | null = null;

  @Column({
    name: 'codigo_redefinicao_senha_enviado_em',
    type: 'timestamptz',
    nullable: true,
    select: false,
  })
  codigoRedefinicaoSenhaEnviadoEm: Date | null = null;

  // =========================
  // DADOS DO USUÁRIO
  // =========================

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

  @Column({
    length: 255,
    nullable: true,
    select: false,
  })
  senha: string | null;

  @CreateDateColumn({ name: 'criado_em', type: 'timestamptz' })
  criadoEm: Date;
}
