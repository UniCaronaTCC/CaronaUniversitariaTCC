import { ConflictException, ServiceUnavailableException } from '@nestjs/common';
import { QueryFailedError, Repository } from 'typeorm';

import { LeituraCnhService } from './leitura-cnh.service';
import { User } from './user.entity';
import { VerificacaoCnhService } from './verificacao-cnh.service';
import { hojeEmSaoPaulo } from './verificacao-cnh';

describe('VerificacaoCnhService', () => {
  const texto = [
    'NOME JOAO PEDRO DA SILVA',
    'CPF 529.982.247-25',
    'CATEGORIA B',
    'VALIDADE 06/10/2099',
    'N REGISTRO 12345678901',
  ].join('\n');
  const frente = Buffer.from('frente');
  const verso = Buffer.from('verso');
  let usuarios: { findOne: jest.Mock; update: jest.Mock };
  let leitura: { ler: jest.Mock };
  let service: VerificacaoCnhService;

  beforeEach(() => {
    usuarios = {
      findOne: jest.fn().mockResolvedValue({
        idUsuario: 1,
        nome: 'João Pedro da Silva',
        statusVerificacaoCnh: 'NAO_ENVIADA',
      }),
      update: jest.fn().mockResolvedValue({ affected: 1 }),
    };
    leitura = { ler: jest.fn().mockResolvedValue(texto) };
    service = new VerificacaoCnhService(
      usuarios as unknown as Repository<User>,
      leitura as unknown as LeituraCnhService,
    );
  });

  it('usa o dia local de São Paulo', () => {
    expect(hojeEmSaoPaulo(new Date('2026-10-07T02:30:00Z'))).toBe('2026-10-06');
  });

  it('aprova e persiste apenas os campos definidos', async () => {
    await expect(service.verificar(1, frente, verso)).resolves.toEqual({
      status: 'APROVADA',
    });
    expect(leitura.ler).toHaveBeenCalledWith(frente, verso);
    const [idUsuario, alteracoes] = usuarios.update.mock.calls[0] as [
      number,
      Partial<User>,
    ];
    expect(idUsuario).toBe(1);
    expect(alteracoes).toMatchObject({
      statusVerificacaoCnh: 'APROVADA',
      cpf: '52998224725',
      cnhCategoria: 'B',
      cnhValidade: '2099-10-06',
      cnhRegistroFinal: '8901',
    });
    expect(alteracoes.cnhVerificadaEm).toBeInstanceOf(Date);
    expect(alteracoes.privacidadeAceitaEm).toBeInstanceOf(Date);
  });

  it('recusa leitura inconclusiva e não guarda dados parciais', async () => {
    leitura.ler.mockResolvedValue('texto ilegível');
    await expect(service.verificar(1, frente, verso)).resolves.toEqual({
      status: 'RECUSADA',
    });
    expect(usuarios.update).toHaveBeenCalledWith(
      1,
      expect.objectContaining({
        statusVerificacaoCnh: 'RECUSADA',
        cpf: null,
        cnhCategoria: null,
        cnhValidade: null,
        cnhRegistroFinal: null,
      }),
    );
  });

  it('não muda o banco quando o OCR falha', async () => {
    leitura.ler.mockRejectedValue(new ServiceUnavailableException());
    await expect(service.verificar(1, frente, verso)).rejects.toBeInstanceOf(
      ServiceUnavailableException,
    );
    expect(usuarios.update).not.toHaveBeenCalled();
  });

  it('não refaz uma aprovação ainda válida', async () => {
    usuarios.findOne.mockResolvedValue({
      idUsuario: 1,
      nome: 'João Pedro da Silva',
      statusVerificacaoCnh: 'APROVADA',
      cnhCategoria: 'B',
      cnhValidade: '2099-10-06',
    });
    await expect(service.verificar(1, frente, verso)).resolves.toEqual({
      status: 'APROVADA',
    });
    expect(leitura.ler).not.toHaveBeenCalled();
    expect(usuarios.update).not.toHaveBeenCalled();
  });

  it('trata CPF já associado sem expor o número', async () => {
    usuarios.update.mockRejectedValue(
      new QueryFailedError('UPDATE', [], {
        code: '23505',
        constraint: 'uq_usuarios_cpf',
      }),
    );
    await expect(service.verificar(1, frente, verso)).rejects.toBeInstanceOf(
      ConflictException,
    );
  });
});
