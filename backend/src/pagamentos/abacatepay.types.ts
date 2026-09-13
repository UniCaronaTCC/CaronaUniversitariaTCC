export interface DadosCriacaoPix {
  valorCentavos: number;
  referencia: string;
  descricao?: string;
  expiraEmSegundos?: number;
}

export const STATUS_PIX = [
  'PENDING',
  'EXPIRED',
  'CANCELLED',
  'PAID',
  'UNDER_DISPUTE',
  'REFUNDED',
  'REDEEMED',
  'APPROVED',
  'FAILED',
] as const;

export type StatusPix = (typeof STATUS_PIX)[number];

export interface ConsultaPix {
  id: string;
  status: StatusPix;
  expiraEm: string;
}

export interface CobrancaPix extends ConsultaPix {
  valorCentavos: number;
  pixCopiaECola: string;
  qrCodeBase64: string;
  modoTeste: true;
}
