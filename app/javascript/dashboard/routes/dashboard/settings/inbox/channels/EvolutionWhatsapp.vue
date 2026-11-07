<script>
import { mapGetters } from 'vuex';
import { useVuelidate } from '@vuelidate/core';
import { useAlert } from 'dashboard/composables';
import { required } from '@vuelidate/validators';
import router from '../../../../index';
import { isPhoneE164OrEmpty } from 'shared/helpers/Validators';
import NextButton from 'dashboard/components-next/button/Button.vue';

export default {
  components: {
    NextButton,
  },
  setup() {
    return { v$: useVuelidate() };
  },
  data() {
    return {
      inboxName: '',
      phoneNumber: '',
      apiHost: 'http://localhost:8080',
      apiKey: '',
      instanceName: '',
    };
  },
  computed: {
    ...mapGetters({ uiFlags: 'inboxes/getUIFlags' }),
  },
  validations: {
    inboxName: { required },
    phoneNumber: { required, isPhoneE164OrEmpty },
    apiHost: { required },
    apiKey: { required },
    instanceName: { required },
  },
  methods: {
    async createChannel() {
      this.v$.$touch();
      if (this.v$.$invalid) {
        return;
      }

      try {
        const whatsappChannel = await this.$store.dispatch(
          'inboxes/createChannel',
          {
            name: this.inboxName?.trim(),
            channel: {
              type: 'whatsapp',
              phone_number: this.phoneNumber,
              provider: 'evolution',
              provider_config: {
                api_host: this.apiHost.trim(),
                api_key: this.apiKey.trim(),
                instance_name: this.instanceName.trim(),
                ignore_messaging_window: true,
              },
            },
          }
        );

        router.replace({
          name: 'settings_inboxes_add_agents',
          params: {
            page: 'new',
            inbox_id: whatsappChannel.id,
          },
        });
      } catch (error) {
        useAlert(
          error.message ||
            'Erro ao criar o canal de WhatsApp Não Oficial. Verifique as credenciais.'
        );
      }
    },
  },
};
</script>

<template>
  <div class="border border-n-weak bg-n-solid-1 rounded-xl p-6 max-w-2xl">
    <div class="mb-6">
      <h2 class="text-lg font-semibold text-n-slate-12">
        WhatsApp Não Oficial (Evolution / Baileys / Whatsmeow)
      </h2>
      <p class="text-xs text-n-slate-11 mt-1">
        Conecte qualquer número via QR Code ou Pairing Code sem janela de 24 horas e sem cobranças por mensagem da Meta.
      </p>
    </div>

    <form class="space-y-4" @submit.prevent="createChannel">
      <div>
        <label class="block text-xs font-medium text-n-slate-11 mb-1.5">
          Nome da Caixa de Entrada
        </label>
        <input
          v-model="inboxName"
          type="text"
          placeholder="Ex: WhatsApp Vendas"
          class="w-full px-3 py-2 text-sm bg-n-background border border-n-weak rounded-lg focus:outline-none focus:border-n-brand text-n-slate-12"
        />
        <span v-if="v$.inboxName.$error" class="text-xs text-red-500 mt-1 block">
          Campo obrigatório
        </span>
      </div>

      <div>
        <label class="block text-xs font-medium text-n-slate-11 mb-1.5">
          Número de Telefone (formato E.164 com DDI e DDD)
        </label>
        <input
          v-model="phoneNumber"
          type="text"
          placeholder="Ex: +5511999998888"
          class="w-full px-3 py-2 text-sm bg-n-background border border-n-weak rounded-lg focus:outline-none focus:border-n-brand text-n-slate-12"
        />
        <span v-if="v$.phoneNumber.$error" class="text-xs text-red-500 mt-1 block">
          Informe um número válido no padrão +5511999998888
        </span>
      </div>

      <div>
        <label class="block text-xs font-medium text-n-slate-11 mb-1.5">
          Host da API / Gateway (URL)
        </label>
        <input
          v-model="apiHost"
          type="text"
          placeholder="http://localhost:8080 ou https://api.seudominio.com"
          class="w-full px-3 py-2 text-sm bg-n-background border border-n-weak rounded-lg focus:outline-none focus:border-n-brand text-n-slate-12"
        />
        <span v-if="v$.apiHost.$error" class="text-xs text-red-500 mt-1 block">
          Campo obrigatório
        </span>
      </div>

      <div>
        <label class="block text-xs font-medium text-n-slate-11 mb-1.5">
          Chave de API (Global API Key)
        </label>
        <input
          v-model="apiKey"
          type="password"
          placeholder="Chave secreta configurada na API"
          class="w-full px-3 py-2 text-sm bg-n-background border border-n-weak rounded-lg focus:outline-none focus:border-n-brand text-n-slate-12"
        />
        <span v-if="v$.apiKey.$error" class="text-xs text-red-500 mt-1 block">
          Campo obrigatório
        </span>
      </div>

      <div>
        <label class="block text-xs font-medium text-n-slate-11 mb-1.5">
          Nome da Instância
        </label>
        <input
          v-model="instanceName"
          type="text"
          placeholder="Ex: atendimento_principal"
          class="w-full px-3 py-2 text-sm bg-n-background border border-n-weak rounded-lg focus:outline-none focus:border-n-brand text-n-slate-12"
        />
        <span v-if="v$.instanceName.$error" class="text-xs text-red-500 mt-1 block">
          Campo obrigatório
        </span>
      </div>

      <div class="pt-4 flex items-center gap-3">
        <NextButton
          type="submit"
          :is-loading="uiFlags.isCreating"
          label="Criar Caixa de Entrada"
        />
      </div>
    </form>
  </div>
</template>

