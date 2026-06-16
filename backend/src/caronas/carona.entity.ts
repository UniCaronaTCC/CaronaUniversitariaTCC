import { Column, CreateDateColumn, Entity, ManyToOne, PrimaryGeneratedColumn } from 'typeorm'; // Importa os decorators do TypeORM para mapear a tabela
import { User } from '../users/user.entity'; // Importa a entidade de usuário para relacionar a carona com quem criou

@Entity('caronas') // Define que esta classe representa a tabela caronas no banco
export class Carona { // Classe que representa uma carona no sistema
  @PrimaryGeneratedColumn({ name: 'id_carona' }) // Define a chave primária com auto incremento
  idCarona: number;

  @Column({ length: 20 }) // Define se a carona é uma solicitação ou uma oferta
  tipo: string;

  @Column({ length: 100 }) // Define a coluna origem 
  origem: string;

  @Column({ length: 100 }) // Define a coluna destino
  destino: string;

  @Column({ type: 'date' }) // Define a data da carona
  data: string;

  @Column({ type: 'time' }) // Define o horário da carona
  horario: string;

  @Column({ nullable: true }) // Define a quantidade de vagas - ofertar
  vagas: number;

  @Column({ type: 'decimal', precision: 10, scale: 2, nullable: true }) // Define o valor da carona - ofertar
  valor: number;

  @Column({ type: 'text', nullable: true }) // observações extras da carona
  observacoes: string;

  @Column({ length: 30, default: 'ATIVA' }) //status da carona
  status: string;

  @ManyToOne(() => User) // Relaciona muitas caronas com um usuário
  usuario: User;

  @CreateDateColumn({ name: 'criado_em' }) // Define a coluna criado em como data automática de criação
  criadoEm: Date;
}