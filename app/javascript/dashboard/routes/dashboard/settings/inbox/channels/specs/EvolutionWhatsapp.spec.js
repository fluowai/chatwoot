import { mount, flushPromises, config } from '@vue/test-utils';
import { createStore } from 'vuex';
import { useRouter } from 'vue-router';
import BrazilToolsAPI from 'dashboard/api/brazilTools';
import EvolutionWhatsapp from '../EvolutionWhatsapp.vue';
import ptBRBrazil from 'dashboard/i18n/locale/pt_BR/brazil.json';

config.global.plugins[0].global.setLocaleMessage('pt_BR', ptBRBrazil);
config.global.plugins[0].global.locale.value = 'pt_BR';

vi.mock('vue-router', () => ({
  useRouter: vi.fn(),
}));

vi.mock('dashboard/composables', () => ({
  useAlert: vi.fn(),
}));

vi.mock('dashboard/api/brazilTools', () => ({
  default: {
    getWhatsappStatus: vi.fn(),
  },
}));

describe('EvolutionWhatsapp.vue', () => {
  beforeEach(() => {
    useRouter.mockReturnValue({ replace: vi.fn() });
    BrazilToolsAPI.getWhatsappStatus.mockResolvedValue({
      data: {
        status: { state: 'connecting' },
        qrcode: {
          base64:
            'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==',
          pairing_code: 'ABCD-1234',
        },
      },
    });
  });

  it('normalizes Brazilian phone to E.164 with 9th digit, creates unofficial channel, and displays QR Code + Pairing Code', async () => {
    const createChannelMock = vi.fn().mockResolvedValue({ id: 77 });
    const store = createStore({
      modules: {
        inboxes: {
          namespaced: true,
          getters: {
            getUIFlags: () => ({ isCreating: false }),
          },
          actions: {
            createChannel: createChannelMock,
          },
        },
      },
    });

    const wrapper = mount(EvolutionWhatsapp, {
      global: {
        plugins: [store],
        stubs: {
          NextButton: false,
        },
      },
    });

    const textInputs = wrapper.findAll('input[type="text"]');
    const passwordInput = wrapper.find('input[type="password"]');

    await textInputs[0].setValue('WhatsApp Comercial');
    await textInputs[1].setValue('1188887777');
    await textInputs[1].trigger('blur');
    await textInputs[2].setValue('http://evolution-api:8080');
    await passwordInput.setValue('global-secret-key');
    await textInputs[3].setValue('comercial_01');

    expect(textInputs[1].element.value).toBe('+5511988887777');

    await wrapper.find('form').trigger('submit.prevent');
    await flushPromises();

    expect(createChannelMock).toHaveBeenCalledWith(expect.anything(), {
      name: 'WhatsApp Comercial',
      channel: {
        type: 'whatsapp',
        phone_number: '+5511988887777',
        provider: 'evolution',
        provider_config: {
          api_host: 'http://evolution-api:8080',
          api_key: 'global-secret-key',
          instance_name: 'comercial_01',
          session_id: 'comercial_01',
          allow_groups: false,
          ignore_messaging_window: true,
        },
      },
    });

    expect(wrapper.text()).toContain('ABCD-1234');
    expect(wrapper.find('img').exists()).toBe(true);
  });
});
