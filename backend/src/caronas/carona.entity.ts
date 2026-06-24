import {
  Column,
  CreateDateColumn,
  Entity,
  JoinColumn,
  ManyToOne,
  PrimaryGeneratedColumn,
} from 'typeorm'; // Importa os decorators do TypeORM para mapear a tabela

import { User } from '../users/user.entity';
// Importa a entidade de usuário para relacionar a carona ao motorista

@Entity('caronas') // Define que esta classe representa a tabela caronas no banco
export class Carona { // Classe que representa uma oferta de carona

  @PrimaryGeneratedColumn({ name: 'id_carona' })
  // O sinal ! informa que o TypeORM preencherá esta propriedade
  idCarona!: number;

  @Column({ length: 100 })
  // Define o local de saída da carona
  origem!: string;

  @Column({ length: 100 })
  // Define o local de destino da carona
  destino!: string;

  @Column({ name: 'data_inicio', type: 'date' })
  // Define a data da carona ou a primeira data de uma recorrência
  dataInicio!: string;

  @Column({
    name: 'data_fim',
    type: 'date',
    nullable: true,
  })
  // Define até quando a carona recorrente será oferecida
  dataFim: string | null = null;

  @Column({ type: 'time' })
  // Define o horário de saída
  horario!: string;

  @Column({ type: 'int', unsigned: true })
  // Define a quantidade de vagas oferecidas
  vagas!: number;

  @Column({
    type: 'decimal',
    precision: 10,
    scale: 2,
  })
  // Define o valor cobrado por passageiro
  valor!: number;

  @Column({ default: false })
  // Define se a carona será repetida
  recorrente: boolean = false;

  @Column({
    name: 'dias_semana',
    type: 'simple-json',
    nullable: true,
  })
  // Exemplo: ["segunda", "quarta", "sexta"]
  diasSemana: string[] | null = null;

  @Column({
    type: 'text',
    nullable: true,
  })
  // Informações adicionais fornecidas pelo motorista
  observacoes: string | null = null;

  @Column({
    length: 30,
    default: 'ATIVA',
  })
  // Define o estado atual da oferta
  status: string = 'ATIVA';

  @ManyToOne(() => User)
  // Relaciona várias caronas a um mesmo motorista
  @JoinColumn({ name: 'id_usuario' })
  // Define o nome da chave estrangeira
  usuario!: User;

  @CreateDateColumn({ name: 'criado_em' })
  // Registra automaticamente quando a carona foi criada
  criadoEm!: Date;
}