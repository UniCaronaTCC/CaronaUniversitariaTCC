import { BadRequestException } from '@nestjs/common';

export function validarValorCarona(entrada: unknown): number {
  if (typeof entrada !== 'number' && typeof entrada !== 'string') {
    throw new BadRequestException('Valor da carona inválido');
  }
  const valor = Number(entrada);
  const centavos = Math.round(valor * 100);
  if (!Number.isFinite(valor) || valor < 1 || centavos < 100) {
    throw new BadRequestException('O valor mínimo por passageiro é R$ 1,00');
  }
  if (
    !Number.isSafeInteger(centavos) ||
    centavos > 9_999_999_999 ||
    Math.abs(valor * 100 - centavos) > 0.000001
  ) {
    throw new BadRequestException(
      'Informe um valor válido com até duas casas decimais',
    );
  }
  return valor;
}
