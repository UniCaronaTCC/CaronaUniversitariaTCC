import { ValueTransformer } from 'typeorm';

// O PostgreSQL devolve BIGINT como texto. A tabela limita o valor ao inteiro seguro.
export const numeroInteiroGrandeTransformer: ValueTransformer = {
  to: (valor: number | null) => valor,
  from: (valor: string | null) => (valor == null ? null : Number(valor)),
};
