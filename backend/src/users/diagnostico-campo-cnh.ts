export type MotivoCampoCnh =
  | 'TITULO_AUSENTE'
  | 'TITULO_DUPLICADO'
  | 'ALTURA_INVALIDA'
  | 'REGIAO_VAZIA'
  | 'PALAVRA_NA_BORDA'
  | 'REGIAO_LOCALIZADA'
  | 'VALOR_AUSENTE'
  | 'VALOR_AMBIGUO'
  | 'FORMATO_INVALIDO'
  | 'OUTRO_CAMPO'
  | 'CAMPO_LIDO'
  | 'CPF_INVALIDO';

export type RelatarCampoCnh = (motivo: MotivoCampoCnh) => void;
