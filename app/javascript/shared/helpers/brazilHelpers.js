const EVP_UUID_REGEX =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

const LEGACY_BR_MOBILE_REGEX = /^[6-9]\d{7}$/;
const CANONICAL_BR_MOBILE_REGEX = /^9([6-9]\d{7})$/;

export const cleanDigits = value => String(value || '').replace(/\D/g, '');

const calculateCpfDigit = (slice, startWeight) => {
  const sum = slice.reduce(
    (acc, num, idx) => acc + num * (startWeight - idx),
    0
  );
  const remainder = (sum * 10) % 11;
  return remainder === 10 ? 0 : remainder;
};

const calculateCnpjDigit = (slice, weights) => {
  const sum = slice.reduce((acc, num, idx) => acc + num * weights[idx], 0);
  const remainder = sum % 11;
  return remainder < 2 ? 0 : 11 - remainder;
};

export const isValidCPF = value => {
  const digits = cleanDigits(value);
  if (digits.length !== 11) return false;
  if (/^(\d)\1{10}$/.test(digits)) return false;

  const nums = digits.split('').map(Number);
  const firstCheck = calculateCpfDigit(nums.slice(0, 9), 10);
  if (nums[9] !== firstCheck) return false;

  const secondCheck = calculateCpfDigit(nums.slice(0, 10), 11);
  return nums[10] === secondCheck;
};

export const isValidCNPJ = value => {
  const digits = cleanDigits(value);
  if (digits.length !== 14) return false;
  if (/^(\d)\1{13}$/.test(digits)) return false;

  const nums = digits.split('').map(Number);
  const weightsFirst = [5, 4, 3, 2, 9, 8, 7, 6, 5, 4, 3, 2];
  const weightsSecond = [6, 5, 4, 3, 2, 9, 8, 7, 6, 5, 4, 3, 2];

  const firstCheck = calculateCnpjDigit(nums.slice(0, 12), weightsFirst);
  if (nums[12] !== firstCheck) return false;

  const secondCheck = calculateCnpjDigit(nums.slice(0, 13), weightsSecond);
  return nums[13] === secondCheck;
};

export const isValidCpfCnpj = value => {
  const digits = cleanDigits(value);
  if (digits.length === 11) return isValidCPF(digits);
  if (digits.length === 14) return isValidCNPJ(digits);
  return false;
};

export const formatCpfCnpj = value => {
  const digits = cleanDigits(value);
  if (digits.length === 11) {
    return `${digits.slice(0, 3)}.${digits.slice(3, 6)}.${digits.slice(6, 9)}-${digits.slice(9, 11)}`;
  }
  if (digits.length === 14) {
    return `${digits.slice(0, 2)}.${digits.slice(2, 5)}.${digits.slice(5, 8)}/${digits.slice(8, 12)}-${digits.slice(12, 14)}`;
  }
  return String(value || '');
};

export const formatCEP = value => {
  const digits = cleanDigits(value).slice(0, 8);
  if (digits.length <= 5) return digits;
  return `${digits.slice(0, 5)}-${digits.slice(5, 8)}`;
};

export const formatBRL = value => {
  const num = Number(value);
  if (Number.isNaN(num)) return 'R$ 0,00';
  return new Intl.NumberFormat('pt-BR', {
    style: 'currency',
    currency: 'BRL',
  }).format(num);
};

export const parseBRLInput = value => {
  if (typeof value === 'number') return value;
  const raw = String(value || '').trim();
  if (!raw) return 0;
  const normalized = raw.includes(',')
    ? raw.replace(/[R$\s.]/g, '').replace(',', '.')
    : raw.replace(/[R$\s]/g, '');
  const parsed = Number.parseFloat(normalized);
  return Number.isNaN(parsed) ? 0 : Math.round(parsed * 100) / 100;
};

export const normalizeBrazilPhone = rawPhone => {
  let digits = cleanDigits(rawPhone);
  if (!digits) return '';

  if (digits.length === 10 || digits.length === 11) {
    digits = `55${digits}`;
  }
  if (!digits.startsWith('55')) {
    return `+${digits}`;
  }

  const ddd = digits.slice(2, 4);
  const subscriber = digits.slice(4);
  if (LEGACY_BR_MOBILE_REGEX.test(subscriber)) {
    return `+55${ddd}9${subscriber}`;
  }
  return `+55${ddd}${subscriber}`;
};

export const brazilPhoneCandidates = rawPhone => {
  const canonical = normalizeBrazilPhone(rawPhone);
  if (!canonical.startsWith('+55')) return [canonical].filter(Boolean);

  const digits = canonical.slice(1);
  const ddd = digits.slice(2, 4);
  const subscriber = digits.slice(4);
  const match = subscriber.match(CANONICAL_BR_MOBILE_REGEX);
  if (!match) {
    return [digits, canonical];
  }
  const legacy = `55${ddd}${match[1]}`;
  return [digits, canonical, legacy, `+${legacy}`];
};

const stripAccents = str =>
  String(str || '')
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '');

const sanitizeEmvText = (str, maxLen) =>
  stripAccents(str)
    .replace(/[^a-zA-Z0-9 ]/g, '')
    .replace(/\s+/g, ' ')
    .trim()
    .slice(0, maxLen);

const formatEmvField = (id, value) => {
  const str = String(value);
  const byteLength = new TextEncoder().encode(str).length;
  const len = String(byteLength).padStart(2, '0');
  return `${id}${len}${str}`;
};

/* eslint-disable no-bitwise -- BACEN EMV BR Code CRC16-CCITT (0x1021) checksum algorithm requires bit-level polynomial operations */
export const computeCrc16 = payload => {
  let crc = 0xffff;
  const bytes = new TextEncoder().encode(payload);
  for (let i = 0; i < bytes.length; i += 1) {
    crc ^= bytes[i] << 8;
    for (let bit = 0; bit < 8; bit += 1) {
      if ((crc & 0x8000) !== 0) {
        crc = ((crc << 1) ^ 0x1021) & 0xffff;
      } else {
        crc = (crc << 1) & 0xffff;
      }
    }
  }
  return crc.toString(16).toUpperCase().padStart(4, '0');
};
/* eslint-enable no-bitwise */

export const normalizePixKey = (key, keyType = '') => {
  const raw = String(key || '').trim();
  if (!raw) return '';
  if (raw.includes('@')) return raw.toLowerCase();
  if (EVP_UUID_REGEX.test(raw)) return raw.toLowerCase();
  if (keyType === 'phone' || raw.startsWith('+')) {
    let digits = cleanDigits(raw);
    if (digits.length === 10 || digits.length === 11) {
      digits = `55${digits}`;
    }
    return `+${digits}`;
  }
  const digits = cleanDigits(raw);
  if (digits.length === 11 || digits.length === 14) {
    return digits;
  }
  return raw;
};

export const generatePixPayload = ({
  key,
  name,
  city = 'SAO PAULO',
  amount = 0,
  txid = '***',
  keyType = '',
  description = '',
}) => {
  const normalizedKey = normalizePixKey(key, keyType);
  const sanitizedName = sanitizeEmvText(name, 25);
  const sanitizedCity = sanitizeEmvText(city || 'SAO PAULO', 15) || 'SAO PAULO';

  if (!normalizedKey) {
    throw new Error('PIX key is required');
  }
  if (!sanitizedName) {
    throw new Error('Merchant name is required');
  }

  const numericAmount = parseBRLInput(amount);
  const rawTxid = String(txid || '').trim();
  const cleanTxid =
    !rawTxid || rawTxid === '***'
      ? '***'
      : stripAccents(rawTxid)
          .replace(/[^a-zA-Z0-9]/g, '')
          .slice(0, 25) || '***';

  const merchantFields = [
    formatEmvField('00', 'br.gov.bcb.pix'),
    formatEmvField('01', normalizedKey),
  ];
  const cleanDesc = sanitizeEmvText(description, 40);
  if (cleanDesc) {
    merchantFields.push(formatEmvField('02', cleanDesc));
  }

  const fields = [
    formatEmvField('00', '01'),
    formatEmvField('26', merchantFields.join('')),
    formatEmvField('52', '0000'),
    formatEmvField('53', '986'),
  ];

  if (numericAmount > 0) {
    fields.push(formatEmvField('54', numericAmount.toFixed(2)));
  }

  fields.push(
    formatEmvField('58', 'BR'),
    formatEmvField('59', sanitizedName),
    formatEmvField('60', sanitizedCity),
    formatEmvField('62', formatEmvField('05', cleanTxid))
  );

  const basePayload = `${fields.join('')}6304`;
  return `${basePayload}${computeCrc16(basePayload)}`;
};

export const buildPixChatMessage = ({
  key,
  name,
  city = 'SAO PAULO',
  amount = 0,
  txid = '***',
  keyType = '',
  description = '',
}) => {
  const payload = generatePixPayload({
    key,
    name,
    city,
    amount,
    txid,
    keyType,
    description,
  });
  const numericAmount = parseBRLInput(amount);
  const lines = [
    '💠 *Pagamento via PIX*',
    `*Recebedor:* ${String(name).trim()}`,
  ];
  if (numericAmount > 0) {
    lines.push(`*Valor:* ${formatBRL(numericAmount)}`);
  }
  if (String(description || '').trim()) {
    lines.push(`*Descrição:* ${String(description).trim()}`);
  }
  lines.push('', '*PIX Copia e Cola:*', payload);
  return { payload, message: lines.join('\n') };
};
