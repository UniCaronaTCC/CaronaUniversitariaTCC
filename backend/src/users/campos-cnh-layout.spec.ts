import type { Block, Word } from './ocr-cnh';
import { valorDoCampo } from './campos-cnh-layout';

const palavra = (
  text: string,
  x0: number,
  y0: number,
  x1: number,
  y1: number,
): Word => ({ text, bbox: { x0, y0, x1, y1 } });
const blocos = (...linhas: Word[][]): Block[] => [
  { paragraphs: [{ lines: linhas.map((words) => ({ words })) }] },
];

describe('separação das colunas da CNH', () => {
  const titulo = palavra('CPF', 560, 436, 590, 448);
  const registro = palavra('REGISTRO', 695, 436, 748, 448);
  const cpf = palavra('529.982.247-25', 540, 450, 650, 465);
  // A caixa começa um pixel antes do limite estimado, mas fica sob REGISTRO.
  const numeroVizinho = palavra('12345678901', 670, 450, 748, 465);

  it('não rejeita o CPF inteiro por sobreposição do número da coluna REGISTRO', () => {
    expect(
      valorDoCampo(
        blocos([titulo, registro], [cpf, numeroVizinho]),
        'cpf',
        1000,
        800,
      ),
    ).toBe('529.982.247-25');
  });

  it('não usa o registro quando não há CPF na célula', () => {
    expect(
      valorDoCampo(
        blocos([titulo, registro], [numeroVizinho]),
        'cpf',
        1000,
        800,
      ),
    ).toBeNull();
  });

  it('continua recusando um CPF que atravessa o limite dentro da própria coluna', () => {
    const cortado = palavra('529.982.247-25', 540, 450, 680, 465);
    expect(
      valorDoCampo(blocos([titulo, registro], [cortado]), 'cpf', 1000, 800),
    ).toBeNull();
  });

  it('não ignora número na borda sem rótulo que confirme a coluna vizinha', () => {
    const cortado = palavra('529.982.247-25', 540, 450, 770, 465);
    expect(
      valorDoCampo(blocos([titulo], [cortado]), 'cpf', 1000, 800),
    ).toBeNull();
  });
});
