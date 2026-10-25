import { BadRequestException } from '@nestjs/common';

type CampoVeiculo = 'modelo' | 'cor' | 'placa';

function invalido(campo: CampoVeiculo, mensagem: string): never {
  throw new BadRequestException({
    message: mensagem,
    campos: { [campo]: mensagem },
  });
}

function texto(valor: unknown, campo: CampoVeiculo, limite: number): string {
  const mensagens = {
    modelo: 'Informe a marca e o modelo v\u00e1lidos',
    cor: 'Informe uma cor v\u00e1lida',
    placa: 'Informe uma placa v\u00e1lida',
  };
  if (typeof valor !== 'string' || /\p{Cc}/u.test(valor)) {
    return invalido(campo, mensagens[campo]);
  }
  const normalizado = valor.trim().replace(/ +/g, ' ');
  if (!normalizado || normalizado.length > limite) {
    return invalido(
      campo,
      campo === 'modelo'
        ? 'Informe a marca e o modelo, com at\u00e9 100 caracteres'
        : campo === 'cor'
          ? 'Informe uma cor com at\u00e9 50 caracteres'
          : 'Informe uma placa v\u00e1lida',
    );
  }
  return normalizado;
}

export function validarDadosVeiculo(body: unknown) {
  const dados =
    body && typeof body === 'object' && !Array.isArray(body)
      ? (body as Record<string, unknown>)
      : {};
  const modelo = texto(dados.modelo, 'modelo', 100);
  const cor = texto(dados.cor, 'cor', 50);
  const placaRecebida = texto(dados.placa, 'placa', 32);

  // Modelos numericos (208) e alfanumericos (C3, HB20) tambem sao validos.
  if (
    modelo.length < 2 ||
    !/^[\p{L}\p{N}][\p{L}\p{N} .+'()/&!,-]*$/u.test(modelo)
  ) {
    invalido('modelo', 'Informe a marca e o modelo v\u00e1lidos');
  }
  if (cor.length < 2 || !/^[\p{L}]+(?:[ -][\p{L}]+)*$/u.test(cor)) {
    invalido('cor', 'Informe uma cor v\u00e1lida');
  }
  const placa = placaRecebida.toUpperCase().replace(/[ -]/g, '');
  if (
    !/^[A-Z0-9 -]+$/i.test(placaRecebida) ||
    !/^[A-Z]{3}(?:\d{4}|\d[A-Z]\d{2})$/.test(placa)
  ) {
    invalido('placa', 'Informe uma placa v\u00e1lida');
  }
  return { modelo, cor, placa };
}
