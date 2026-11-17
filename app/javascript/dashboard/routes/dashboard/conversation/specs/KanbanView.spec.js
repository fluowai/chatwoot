import { mount, flushPromises, config } from '@vue/test-utils';
import { createStore } from 'vuex';
import { useRoute, useRouter } from 'vue-router';
import KanbanView from '../KanbanView.vue';
import ptBRBrazil from 'dashboard/i18n/locale/pt_BR/brazil.json';

config.global.plugins[0].global.setLocaleMessage('pt_BR', ptBRBrazil);
config.global.plugins[0].global.locale.value = 'pt_BR';

vi.mock('vue-router', () => ({
  useRoute: vi.fn(),
  useRouter: vi.fn(),
}));

vi.mock('dashboard/composables', () => ({
  useAlert: vi.fn(),
}));

describe('KanbanView.vue', () => {
  beforeEach(() => {
    useRoute.mockReturnValue({ params: { accountId: '1' } });
    useRouter.mockReturnValue({ push: vi.fn() });
  });

  const createVuexStore = () => {
    const fetchAllConversations = vi.fn().mockResolvedValue();
    const updateCustomAttributes = vi.fn().mockResolvedValue();
    const createLabel = vi.fn().mockResolvedValue();

    const store = createStore({
      modules: {
        conversations: {
          namespaced: true,
          getters: {
            getAllConversations: () => [
              {
                id: 101,
                inbox_id: 1,
                labels: ['lead'],
                custom_attributes: { valor_negocio: 1500 },
                meta: {
                  sender: {
                    name: 'João Silva',
                    phone_number: '+5511999991111',
                  },
                  assignee: { name: 'Maria' },
                },
                messages: [{ content: 'Tenho interesse no plano anual' }],
              },
              {
                id: 102,
                inbox_id: 1,
                labels: ['negociacao'],
                custom_attributes: { valor_negocio: 1000 },
                meta: {
                  sender: {
                    name: 'Empresa ABC',
                    phone_number: '+5511988882222',
                  },
                },
                messages: [{ content: 'Envie o PIX por favor' }],
              },
            ],
          },
          actions: {
            fetchAllConversations,
            updateCustomAttributes,
          },
        },
        conversationLabels: {
          namespaced: true,
          getters: {
            getConversationLabels: () => () => [],
          },
          actions: {
            update: vi.fn().mockResolvedValue(),
          },
        },
        inboxes: {
          namespaced: true,
          getters: {
            getInboxes: () => [{ id: 1, name: 'WhatsApp Comercial' }],
          },
          actions: {
            get: vi.fn().mockResolvedValue(),
          },
        },
        labels: {
          namespaced: true,
          getters: {
            getLabels: () => [{ title: 'lead' }],
          },
          actions: {
            get: vi.fn().mockResolvedValue(),
            create: createLabel,
          },
        },
      },
    });

    return {
      store,
      fetchAllConversations,
      updateCustomAttributes,
      createLabel,
    };
  };

  it('renders all Brazilian funnel stages, calculates BRL totals, and creates missing labels', async () => {
    const { store, fetchAllConversations, createLabel } = createVuexStore();

    const wrapper = mount(KanbanView, {
      global: {
        plugins: [store],
        stubs: {
          NextButton: false,
        },
      },
    });

    await flushPromises();

    expect(fetchAllConversations).toHaveBeenCalled();
    expect(wrapper.text()).toContain('Funil de Vendas (Kanban CRM)');
    expect(wrapper.text()).toContain('João Silva');
    expect(wrapper.text()).toContain('Empresa ABC');
    expect(wrapper.text()).toContain('2.500,00');

    const createLabelsBtn = wrapper
      .findAll('button')
      .find(b => b.text().includes('Criar Etiquetas do Funil'));
    expect(createLabelsBtn).toBeTruthy();

    await createLabelsBtn.trigger('click');
    await flushPromises();
    expect(createLabel).toHaveBeenCalledTimes(4);
  });
});
