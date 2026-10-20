import { BadRequestException, Injectable, Logger } from '@nestjs/common';
import {
  nomePeloLayout,
  type LeituraCnh,
  type DiagnosticoRegiaoNome,
} from './nome-cnh-layout';
import { valorDoCampo } from './campos-cnh-layout';
import type { Block, Word } from './ocr-cnh';
const objeto = (valor: unknown): valor is Record<string, unknown> =>
  !!valor && typeof valor === 'object' && !Array.isArray(valor);
@Injectable()
export class LeituraCnhService {
  private readonly logger = new Logger(LeituraCnhService.name);
  // O OCR roda no celular. Aqui validamos o contrato e separamos os campos.
  ler(entrada: unknown): LeituraCnh {
    const invalido = () =>
      new BadRequestException(
        'Leitura da CNH inválida. Atualize o app e fotografe novamente.',
      );
    if (
      !objeto(entrada) ||
      !Array.isArray(entrada.linhas) ||
      entrada.linhas.length > 200
    )
      throw invalido();
    const { largura, altura } = entrada;
    if (
      typeof largura !== 'number' ||
      typeof altura !== 'number' ||
      !Number.isInteger(largura) ||
      !Number.isInteger(altura) ||
      Math.min(largura, altura) < 400 ||
      Math.max(largura, altura) < 600 ||
      largura * altura > 20_000_000
    )
      throw invalido();
    let total = 0;
    const linhas = entrada.linhas.map((linha: unknown) => {
      if (
        !objeto(linha) ||
        !Array.isArray(linha.palavras) ||
        linha.palavras.length > 80
      )
        throw invalido();
      const words = linha.palavras.map((p: unknown): Word => {
        if (
          !objeto(p) ||
          typeof p.texto !== 'string' ||
          !p.texto.trim() ||
          p.texto.length > 150 ||
          [...p.texto].some((c) => c.charCodeAt(0) < 32)
        )
          throw invalido();
        const { x0, y0, x1, y1 } = p;
        if (
          ![x0, y0, x1, y1].every(
            (n) => typeof n === 'number' && Number.isFinite(n),
          )
        )
          throw invalido();
        const caixa = { x0, y0, x1, y1 } as Word['bbox'];
        if (
          caixa.x0 < 0 ||
          caixa.y0 < 0 ||
          caixa.x1 <= caixa.x0 ||
          caixa.y1 <= caixa.y0 ||
          caixa.x1 > largura ||
          caixa.y1 > altura
        )
          throw invalido();
        total += p.texto.length;
        if (total > 15000) throw invalido();
        return { text: p.texto.trim(), bbox: caixa };
      });
      return { words };
    });
    const blocos: Block[] = [{ paragraphs: [{ lines: linhas }] }];
    let diagnosticoNome: DiagnosticoRegiaoNome | undefined;
    const nome = nomePeloLayout(blocos, (diagnostico) => {
      diagnosticoNome = diagnostico;
      this.logger.log(`CNH: regiao_nome ${JSON.stringify(diagnostico)}`);
    });
    const campos = {
      cpf: valorDoCampo(blocos, 'cpf', largura, altura),
      validade: valorDoCampo(blocos, 'validade', largura, altura),
      categoria: valorDoCampo(blocos, 'categoria', largura, altura),
    };
    this.logger.log(
      'CNH: campos_lidos ' +
        JSON.stringify({
          nome: !!nome,
          cpf: !!campos.cpf,
          validade: !!campos.validade,
          categoria: !!campos.categoria,
        }),
    );
    return { texto: '', nome, campos, diagnosticoNome };
  }
}
