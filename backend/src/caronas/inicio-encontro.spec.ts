import { ValidacaoCarona } from './validacao-carona';

describe('Publicacao iniciada pelo primeiro encontro', () => {
  const validacao = new ValidacaoCarona();
  const ponto = {
    nome: 'Portaria',
    endereco: 'Rua A, 10',
    latitude: -21.2,
    longitude: -50.4,
  };
  const dados = {
    destino: 'Campus',
    destinoLatitude: -21.1,
    destinoLongitude: -50.3,
    dataInicio: '2099-12-01',
    horario: '18:00:00',
    vagas: 3,
    valor: 5,
    recorrente: false,
    pontosEmbarque: [ponto],
  };

  it('publica sem origem manual usando as coordenadas do encontro', () => {
    expect(validacao.validarDadosCarona(dados, 7)).toMatchObject({
      idUsuario: 7,
      origem: ponto.endereco,
      origemLatitude: ponto.latitude,
      origemLongitude: ponto.longitude,
      origemCidade: null,
    });
  });

  it('nao grava uma origem ou cidade do GPS divergente enviada pelo cliente', () => {
    const r = validacao.validarDadosCarona(
      {
        ...dados,
        origem: 'Casa particular',
        origemLatitude: -25,
        origemLongitude: -55,
        origemCidade: 'Outra cidade',
      },
      7,
    );
    expect(r.origem).toBe(ponto.endereco);
    expect(r.origemCidade).toBeNull();
    expect(r.origemLatitude).toBe(ponto.latitude);
    expect(r.origemLongitude).toBe(ponto.longitude);
  });

  it('mantem a sequencia enviada, normaliza ordem e usa o primeiro encontro', () => {
    const r = validacao.validarDadosCarona(
      {
        ...dados,
        pontosEmbarque: [
          { ...ponto, ordem: 99 },
          { ...ponto, endereco: 'Rua B', latitude: -21.3, ordem: 1 },
        ],
      },
      7,
    );
    expect(r.origem).toBe(ponto.endereco);
    expect(r.pontosEmbarque.map((p) => p.ordem)).toEqual([1, 2]);
    expect(r.pontosEmbarque[1].endereco).toBe('Rua B');
  });

  it('recorrencia tambem usa o primeiro encontro', () => {
    const r = validacao.validarDadosCarona(
      { ...dados, recorrente: true, diasSemana: ['SEG'] },
      7,
    );
    expect(r.origem).toBe(ponto.endereco);
    expect(r.recorrente).toBe(true);
  });

  it.each([undefined, null, []])(
    'rejeita publicacao sem encontros: %j',
    (pontosEmbarque) => {
      expect(() =>
        validacao.validarDadosCarona({ ...dados, pontosEmbarque }, 7),
      ).toThrow('ponto de encontro');
    },
  );

  it.each([
    null,
    {},
    { ...ponto, endereco: '' },
    { ...ponto, endereco: 'a'.repeat(256) },
    { ...ponto, latitude: null },
    { ...ponto, latitude: 91 },
    { ...ponto, latitude: true },
    { ...ponto, longitude: null },
    { ...ponto, longitude: -181 },
    { ...ponto, longitude: 'erro' },
  ])('rejeita encontro invalido %j', (invalido) => {
    expect(() =>
      validacao.validarDadosCarona({ ...dados, pontosEmbarque: [invalido] }, 7),
    ).toThrow();
  });

  it('rejeita encontros duplicados mesmo com outro nome ou endereco', () => {
    expect(() =>
      validacao.validarDadosCarona(
        {
          ...dados,
          pontosEmbarque: [
            ponto,
            { ...ponto, nome: 'Outro nome', endereco: 'Outro endereco' },
          ],
        },
        7,
      ),
    ).toThrow('duplicados');
  });

  it('nao deriva novamente a origem de uma carona existente ao editar', () => {
    const r = validacao.validarEdicaoCarona(
      {
        ...dados,
        origem: 'Origem antiga',
        origemCidade: 'Cidade antiga',
        origemLatitude: -22,
        origemLongitude: -51,
        capacidadePassageiros: 3,
        capacidadeAnterior: 3,
      },
      7,
    );
    expect(r).toMatchObject({
      origem: 'Origem antiga',
      origemCidade: 'Cidade antiga',
      origemLatitude: -22,
      origemLongitude: -51,
    });
    expect(r.pontosEmbarque[0].endereco).toBe(ponto.endereco);
  });

  it('mantem validacao da origem no contrato de edicao, sem altera-la silenciosamente', () => {
    expect(() =>
      validacao.validarEdicaoCarona(
        { ...dados, capacidadePassageiros: 3, capacidadeAnterior: 3 },
        7,
      ),
    ).toThrow();
  });
});
