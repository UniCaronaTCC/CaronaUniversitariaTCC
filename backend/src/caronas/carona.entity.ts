import {
  Column,
  CreateDateColumn,
  Entity,
  JoinColumn,
  ManyToOne,
  PrimaryGeneratedColumn,
} from 'typeorm'; // Importa os decorators do TypeORM para mapear a tabela

import { User } from '../users/user.entity'; // Importa a entidade de usuário para relacionar a carona com quem criou

@Entity('caronas') // Define que esta classe representa a tabela caronas no banco
export class Carona { // Classe que representa uma carona no sistema

  @PrimaryGeneratedColumn({ name: 'id_carona' }) // Define a chave primária com auto incremento
  idCarona: number;

  @Column({ length: 100 }) // Define a coluna origem com limite de 100 caracteres
  origem: string;

  @Column({ length: 100 }) // Define a coluna destino com limite de 100 caracteres
  destino: string;

  @Column({ type: 'date' }) // Define a data da carona
  data: string;

  @Column({ type: 'time' }) // Define o horário da carona
  horario: string;

  @Column({ type: 'text', nullable: true }) // Define observações extras da carona
  observacoes: string;

  @Column({ length: 30, default: 'ATIVA' }) // Define o status da carona
  status: string;

  @ManyToOne(() => User) // Relaciona muitas caronas com um usuário
  @JoinColumn({ name: 'id_usuario' }) // Define o nome da chave estrangeira no banco
  usuario: User;

  @CreateDateColumn({ name: 'criado_em' }) // Define a coluna criado_em como data automática de criação
  criadoEm: Date;
}