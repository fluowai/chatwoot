import { mount, flushPromises, config } from '@vue/test-utils';
import QRCode from 'qrcode';
import PixChargeModal from '../PixChargeModal.vue';
import ptBRBrazil from 'dashboard/i18n/locale/pt_BR/brazil.json';

config.global.plugins[0].global.setLocaleMessage('pt_BR', ptBRBrazil);
config.global.plugins[0].global.locale.value = 'pt_BR';

vi.mock('qrcode', () => ({
  default: {
    toDataURL: vi.fn(),
  },
}));

vi.mock('dashboard/composables', () => ({
  useAlert: vi.fn(),
}));

describe('PixChargeModal.vue', () => {
  beforeEach(() => {
    QRCode.toDataURL.mockResolvedValue(
      'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg=='
    );
  });

  it('generates EMV PIX payload, QR Code, and emits sendPixWithQr with PNG file', async () => {
    const wrapper = mount(PixChargeModal, {
      props: {
        show: true,
        accountName: 'Fluow Brasil',
      },
      global: {
        stubs: {
          Teleport: true,
          NextButton: false,
        },
      },
    });

    const inputs = wrapper.findAll('input');
    await inputs[0].setValue('250,00');
    await inputs[1].setValue('11.222.333/0001-81');
    await inputs[2].setValue('Fluow Brasil');

    const generateBtn = wrapper
      .findAll('button')
      .find(b => b.text().includes('Gerar QR Code PIX'));
    await generateBtn.trigger('click');
    await flushPromises();

    const textarea = wrapper.find('textarea');
    expect(textarea.exists()).toBe(true);
    expect(textarea.element.value).toContain('0014br.gov.bcb.pix');
    expect(textarea.element.value).toContain('5406250.00');

    const sendBtn = wrapper
      .findAll('button')
      .find(b => b.text().includes('Enviar PIX + Imagem QR Code'));
    await sendBtn.trigger('click');
    await flushPromises();

    const emitted = wrapper.emitted('sendPixWithQr');
    expect(emitted).toBeTruthy();
    expect(emitted[0][0].message).toContain('*Pagamento via PIX*');
    expect(emitted[0][0].qrFile).toBeInstanceOf(File);
  });
});
