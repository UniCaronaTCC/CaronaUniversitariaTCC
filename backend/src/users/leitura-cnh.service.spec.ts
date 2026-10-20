import { BadRequestException } from '@nestjs/common';
import { LeituraCnhService } from './leitura-cnh.service';
import { conferirDadosCnh } from './dados-cnh';

const palavra = (texto: string, x0: number, y0: number, largura = 60) => ({
  texto,
  x0,
  y0,
  x1: x0 + largura,
  y1: y0 + 10,
});
export const leituraTeste = () => ({
  largura: 1000,
  altura: 800,
  linhas: [
    { palavras: [palavra('NOME', 100, 20)] },
    { palavras: [palavra('MARIA', 100, 40), palavra('SILVA', 165, 40)] },
    { palavras: [palavra('CPF', 100, 150), palavra('REGISTRO', 400, 150)] },
    {
      palavras: [
        palavra('529.982.247-25', 100, 170, 140),
        palavra('12345678901', 400, 170, 130),
      ],
    },
    { palavras: [palavra('EMISSAO', 100, 250), palavra('VALIDADE', 400, 250)] },
    {
      palavras: [
        palavra('01/01/2020', 100, 270, 100),
        palavra('01/01/2099', 400, 270, 100),
      ],
    },
    { palavras: [palavra('CAT.HAB.', 700, 350, 80)] },
    { palavras: [palavra('AB', 700, 370, 30)] },
  ],
});

describe('LeituraCnhService com ML Kit', () => {
  const service = new LeituraCnhService();
  it('separa pelas posições, sem confundir CPF/registro ou emissão/validade', () => {
    const l = service.ler(leituraTeste());
    expect(l.nome).toBe('MARIA SILVA');
    expect(l.campos).toEqual({
      cpf: '529.982.247-25',
      validade: '01/01/2099',
      categoria: 'AB',
    });
    expect(conferirDadosCnh(l, 'Maria Silva', '2026-10-20').dados).toEqual({
      cpf: '52998224725',
      validade: '2099-01-01',
      categoria: 'AB',
    });
    expect(conferirDadosCnh(l, 'Outra Pessoa', '2026-10-20').motivo).toBe(
      'NOME_DIVERGENTE',
    );
  });
  it.each([
    null,
    {},
    { largura: 1000, altura: 800, linhas: 'texto' },
    { largura: -1, altura: 800, linhas: [] },
    { largura: 6000, altura: 6000, linhas: [] },
  ])('recusa contrato inválido', (entrada) => {
    expect(() => service.ler(entrada)).toThrow(BadRequestException);
  });
  it('recusa caixa fora da imagem e texto excessivo', () => {
    const l = leituraTeste();
    l.linhas[0].palavras[0].x1 = 1001;
    expect(() => service.ler(l)).toThrow(BadRequestException);
    l.linhas[0].palavras[0] = palavra('A'.repeat(151), 0, 0);
    expect(() => service.ler(l)).toThrow(BadRequestException);
  });
  it('recusa rótulo duplicado e não inventa campo ausente', () => {
    const l = leituraTeste();
    l.linhas.push({ palavras: [palavra('CPF', 300, 600)] });
    expect(service.ler(l).campos?.cpf).toBeNull();
    expect(
      service.ler({ largura: 1000, altura: 800, linhas: [] }).nome,
    ).toBeNull();
  });
});
