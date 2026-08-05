import {
  Column,
  CreateDateColumn,
  Entity,
  PrimaryGeneratedColumn,
} from 'typeorm'; // Importa os decorators do TypeORM para mapear a tabela

@Entity('usuarios') // Define que esta classe representa a tabela usuarios no banco
export class User {
  // Classe que representa um usuário do sistema
  @PrimaryGeneratedColumn({ name: 'id_usuario' }) // Define a chave primária com auto incremento
  idUsuario: number;

  @Column({ length: 100 }) // Define a coluna nome com limite de 100 caracteres
  nome: string;

  @Column({ length: 100, unique: true }) // Define a coluna email com limite de 100 caracteres e valor único
  email: string;

  @Column({ type: 'varchar', length: 150, nullable: true })
  instituicao: string | null = null;

  @Column({ type: 'varchar', length: 150, nullable: true })
  campus: string | null = null;

  @Column({
    name: 'tipo_perfil',
    type: 'varchar',
    length: 20,
    default: 'PASSAGEIRO',
  })
  tipoPerfil: string = 'PASSAGEIRO';

  @Column({
    name: 'status_verificacao',
    type: 'varchar',
    length: 20,
    default: 'NAO_ENVIADO',
  })
  statusVerificacao: string = 'NAO_ENVIADO';

  @Column({ length: 255, select: false }) // Evita carregar o hash da senha em consultas comuns
  senha: string;

  @CreateDateColumn({ name: 'criado_em' }) // Define a coluna criado_em como data automática de criação
  criadoEm: Date;
}
