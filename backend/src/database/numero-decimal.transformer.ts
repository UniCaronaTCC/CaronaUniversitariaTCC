import { ValueTransformer } from 'typeorm';

// O PostgreSQL devolve valores DECIMAL como texto. Aqui eles voltam a ser número.
export const numeroDecimalTransformer: ValueTransformer = {
  to: (valor: number | null) => valor,
  from: (valor: string | null) => (valor == null ? null : Number(valor)),
};
