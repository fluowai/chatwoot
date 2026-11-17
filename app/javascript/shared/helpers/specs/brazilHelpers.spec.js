import {
  isValidCPF,
  isValidCNPJ,
  isValidCpfCnpj,
  formatCpfCnpj,
  formatCEP,
  formatBRL,
  parseBRLInput,
  normalizeBrazilPhone,
  brazilPhoneCandidates,
  computeCrc16,
  generatePixPayload,
  buildPixChatMessage,
} from '../brazilHelpers';

describe('brazilHelpers', () => {
  describe('CPF and CNPJ validation & formatting', () => {
    it('validates authentic CPFs and rejects invalid or repeated digits', () => {
      expect(isValidCPF('52998224725')).toBe(true);
      expect(isValidCPF('529.982.247-25')).toBe(true);
      expect(isValidCPF('111.111.111-11')).toBe(false);
      expect(isValidCPF('52998224720')).toBe(false);
      expect(isValidCPF('12345')).toBe(false);
    });

    it('validates authentic CNPJs and rejects invalid check digits', () => {
      expect(isValidCNPJ('11222333000181')).toBe(true);
      expect(isValidCNPJ('11.222.333/0001-81')).toBe(true);
      expect(isValidCNPJ('00.000.000/0000-00')).toBe(false);
      expect(isValidCNPJ('11.222.333/0001-89')).toBe(false);
    });

    it('formats CPF and CNPJ strings cleanly', () => {
      expect(isValidCpfCnpj('52998224725')).toBe(true);
      expect(isValidCpfCnpj('11222333000181')).toBe(true);
      expect(formatCpfCnpj('52998224725')).toBe('529.982.247-25');
      expect(formatCpfCnpj('11222333000181')).toBe('11.222.333/0001-81');
    });
  });

  describe('CEP and BRL helpers', () => {
    it('formats CEP as NNNNN-NNN', () => {
      expect(formatCEP('01001000')).toBe('01001-000');
      expect(formatCEP('01001-000')).toBe('01001-000');
    });

    it('parses Brazilian currency strings and formats BRL', () => {
      expect(parseBRLInput('1.250,50')).toBe(1250.5);
      expect(parseBRLInput('R$ 149,90')).toBe(149.9);
      expect(parseBRLInput(99.5)).toBe(99.5);
      expect(formatBRL(1250.5)).toContain('1.250,50');
    });
  });

  describe('Brazilian 9th-digit phone normalization', () => {
    it('adds 9th digit to 8-digit legacy mobile numbers', () => {
      expect(normalizeBrazilPhone('551188887777')).toBe('+5511988887777');
      expect(normalizeBrazilPhone('11988887777')).toBe('+5511988887777');
    });

    it('preserves 8-digit Brazilian landlines starting with 2-5', () => {
      expect(normalizeBrazilPhone('551132224444')).toBe('+551132224444');
    });

    it('expands both 8-digit and 9-digit candidates for contact lookup', () => {
      const candidates = brazilPhoneCandidates('+5511988887777');
      expect(candidates).toContain('+5511988887777');
      expect(candidates).toContain('5511988887777');
      expect(candidates).toContain('+551188887777');
      expect(candidates).toContain('551188887777');
    });
  });

  describe('BACEN EMV BR Code PIX generator', () => {
    it('preserves *** default txid and generates valid CRC16 checksum', () => {
      const payload = generatePixPayload({
        key: '11.222.333/0001-81',
        name: 'Fluow Tecnologia',
        city: 'São Paulo',
        amount: '150,00',
        txid: '***',
      });

      expect(payload.startsWith('000201')).toBe(true);
      expect(payload).toContain('0014br.gov.bcb.pix011411222333000181');
      expect(payload).toContain('5303986');
      expect(payload).toContain('5406150.00');
      expect(payload).toContain('5802BR');
      expect(payload).toContain('5916Fluow Tecnologia');
      expect(payload).toContain('6009Sao Paulo');
      expect(payload).toContain('62070503***');

      const bodyWithoutCrc = payload.slice(0, -4);
      const crc = payload.slice(-4);
      expect(computeCrc16(bodyWithoutCrc)).toBe(crc);
    });

    it('builds complete WhatsApp PIX Copia e Cola message', () => {
      const { payload, message } = buildPixChatMessage({
        key: 'financeiro@fluow.com.br',
        name: 'Fluow AI',
        city: 'SAO PAULO',
        amount: '99,90',
        description: 'Plano Mensal',
      });

      expect(message).toContain('*Pagamento via PIX*');
      expect(message).toContain('99,90');
      expect(message).toContain('Plano Mensal');
      expect(message).toContain(payload);
    });
  });
});
