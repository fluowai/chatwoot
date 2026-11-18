<script setup>
import { ref, computed } from 'vue';
import { useStore } from 'vuex';
import { useRouter } from 'vue-router';
import { useI18n } from 'vue-i18n';
import { useVuelidate } from '@vuelidate/core';
import { required } from '@vuelidate/validators';
import QRCode from 'qrcode';
import { useAlert } from 'dashboard/composables';
import { copyTextToClipboard } from 'shared/helpers/clipboard';
import { isPhoneE164OrEmpty } from 'shared/helpers/Validators';
import { normalizeBrazilPhone } from 'shared/helpers/brazilHelpers';
import BrazilToolsAPI from 'dashboard/api/brazilTools';
import NextButton from 'dashboard/components-next/button/Button.vue';

const store = useStore();
const router = useRouter();
const { t } = useI18n();

const providerEngine = ref('evolution');
const inboxName = ref('');
const phoneNumber = ref('');
const apiHost = ref(
  window.globalConfig?.EVOLUTION_API_HOST || 'http://chatwoot-evolution:8080'
);
const apiKey = ref('');
const instanceName = ref('');
const allowGroups = ref(false);

const createdInboxId = ref(null);
const isLoadingQr = ref(false);
const qrDataUrl = ref('');
const pairingCode = ref('');
const connectionState = ref('');

const uiFlags = computed(() => store.getters['inboxes/getUIFlags'] || {});

const rules = computed(() => ({
  inboxName: { required },
  phoneNumber: { required, isPhoneE164OrEmpty },
  apiHost: { required },
  apiKey: providerEngine.value === 'evolution' ? { required } : {},
  instanceName: { required },
}));

const v$ = useVuelidate(rules, {
  inboxName,
  phoneNumber,
  apiHost,
  apiKey,
  instanceName,
});

const webhookPreviewUrl = computed(() => {
  const origin = window.location.origin;
  const normalized =
    normalizeBrazilPhone(phoneNumber.value) || '+5511999998888';
  return `${origin}/webhooks/whatsapp/${encodeURIComponent(normalized)}`;
});

const onPhoneBlur = () => {
  if (!phoneNumber.value) return;
  phoneNumber.value = normalizeBrazilPhone(phoneNumber.value);
};

const copyWebhook = async () => {
  await copyTextToClipboard(webhookPreviewUrl.value);
  useAlert(t('BRAZIL_WHATSAPP.WEBHOOK_COPIED'));
};

const loadQrCode = async () => {
  if (!createdInboxId.value) return;
  isLoadingQr.value = true;
  try {
    const { data } = await BrazilToolsAPI.getWhatsappStatus({
      inboxId: createdInboxId.value,
      includeQr: true,
    });
    connectionState.value = data?.status?.state || '';
    pairingCode.value = data?.qrcode?.pairing_code || '';
    const rawBase64 = data?.qrcode?.base64 || '';
    const rawCode = data?.qrcode?.code || '';
    if (rawBase64) {
      qrDataUrl.value = rawBase64.startsWith('data:image')
        ? rawBase64
        : `data:image/png;base64,${rawBase64}`;
    } else if (rawCode) {
      qrDataUrl.value = await QRCode.toDataURL(rawCode, {
        width: 240,
        margin: 2,
      });
    }
  } catch (error) {
    useAlert(error.message || t('BRAZIL_WHATSAPP.CREATE_ERROR'));
  } finally {
    isLoadingQr.value = false;
  }
};

const goToAddAgents = () => {
  if (!createdInboxId.value) return;
  router.replace({
    name: 'settings_inboxes_add_agents',
    params: {
      page: 'new',
      inbox_id: createdInboxId.value,
    },
  });
};

const createChannel = async () => {
  onPhoneBlur();
  v$.value.$touch();
  if (v$.value.$invalid) return;

  try {
    const whatsappChannel = await store.dispatch('inboxes/createChannel', {
      name: inboxName.value.trim(),
      channel: {
        type: 'whatsapp',
        phone_number: phoneNumber.value.trim(),
        provider: providerEngine.value,
        provider_config: {
          api_host: apiHost.value.trim(),
          api_key: apiKey.value.trim(),
          instance_name: instanceName.value.trim(),
          session_id: instanceName.value.trim(),
          allow_groups: allowGroups.value,
          ignore_messaging_window: true,
        },
      },
    });

    createdInboxId.value = whatsappChannel.id;
    await loadQrCode();
    if (!qrDataUrl.value && !pairingCode.value) {
      goToAddAgents();
    }
  } catch (error) {
    useAlert(error.message || t('BRAZIL_WHATSAPP.CREATE_ERROR'));
  }
};
</script>

<template>
  <div class="border border-n-weak bg-n-solid-1 rounded-xl p-6 max-w-2xl">
    <div class="mb-6">
      <h2 class="text-lg font-semibold text-n-slate-12">
        {{ $t('BRAZIL_WHATSAPP.TITLE') }}
      </h2>
      <p class="text-xs text-n-slate-11 mt-1">
        {{ $t('BRAZIL_WHATSAPP.SUBTITLE') }}
      </p>
    </div>

    <form
      v-if="!createdInboxId"
      class="space-y-4"
      @submit.prevent="createChannel"
    >
      <div>
        <label class="block text-xs font-medium text-n-slate-11 mb-1.5">
          {{ $t('BRAZIL_WHATSAPP.PROVIDER_ENGINE_LABEL') }}
        </label>
        <select
          v-model="providerEngine"
          class="w-full px-3 py-2 text-sm bg-n-background border border-n-weak rounded-lg focus:outline-none focus:border-n-brand text-n-slate-12"
        >
          <option value="evolution">
            {{ $t('BRAZIL_WHATSAPP.PROVIDER_EVOLUTION') }}
          </option>
          <option value="baileys">
            {{ $t('BRAZIL_WHATSAPP.PROVIDER_BAILEYS') }}
          </option>
          <option value="whatsmeow">
            {{ $t('BRAZIL_WHATSAPP.PROVIDER_WHATSMEOW') }}
          </option>
        </select>
      </div>

      <div>
        <label class="block text-xs font-medium text-n-slate-11 mb-1.5">
          {{ $t('BRAZIL_WHATSAPP.INBOX_NAME_LABEL') }}
        </label>
        <input
          v-model="inboxName"
          type="text"
          :placeholder="$t('BRAZIL_WHATSAPP.INBOX_NAME_PLACEHOLDER')"
          class="w-full px-3 py-2 text-sm bg-n-background border border-n-weak rounded-lg focus:outline-none focus:border-n-brand text-n-slate-12"
        />
        <span
          v-if="v$.inboxName.$error"
          class="text-xs text-n-ruby-11 mt-1 block"
        >
          {{ $t('BRAZIL_WHATSAPP.REQUIRED_FIELD') }}
        </span>
      </div>

      <div>
        <label class="block text-xs font-medium text-n-slate-11 mb-1.5">
          {{ $t('BRAZIL_WHATSAPP.PHONE_LABEL') }}
        </label>
        <input
          v-model="phoneNumber"
          type="text"
          :placeholder="$t('BRAZIL_WHATSAPP.PHONE_PLACEHOLDER')"
          class="w-full px-3 py-2 text-sm bg-n-background border border-n-weak rounded-lg focus:outline-none focus:border-n-brand text-n-slate-12"
          @blur="onPhoneBlur"
        />
        <span
          v-if="v$.phoneNumber.$error"
          class="text-xs text-n-ruby-11 mt-1 block"
        >
          {{ $t('BRAZIL_WHATSAPP.PHONE_ERROR') }}
        </span>
      </div>

      <div>
        <label class="block text-xs font-medium text-n-slate-11 mb-1.5">
          {{ $t('BRAZIL_WHATSAPP.API_HOST_LABEL') }}
        </label>
        <input
          v-model="apiHost"
          type="text"
          :placeholder="$t('BRAZIL_WHATSAPP.API_HOST_PLACEHOLDER')"
          class="w-full px-3 py-2 text-sm bg-n-background border border-n-weak rounded-lg focus:outline-none focus:border-n-brand text-n-slate-12"
        />
        <span
          v-if="v$.apiHost.$error"
          class="text-xs text-n-ruby-11 mt-1 block"
        >
          {{ $t('BRAZIL_WHATSAPP.REQUIRED_FIELD') }}
        </span>
      </div>

      <div>
        <label class="block text-xs font-medium text-n-slate-11 mb-1.5">
          {{ $t('BRAZIL_WHATSAPP.API_KEY_LABEL') }}
        </label>
        <input
          v-model="apiKey"
          type="password"
          :placeholder="$t('BRAZIL_WHATSAPP.API_KEY_PLACEHOLDER')"
          class="w-full px-3 py-2 text-sm bg-n-background border border-n-weak rounded-lg focus:outline-none focus:border-n-brand text-n-slate-12"
        />
        <span v-if="v$.apiKey.$error" class="text-xs text-n-ruby-11 mt-1 block">
          {{ $t('BRAZIL_WHATSAPP.REQUIRED_FIELD') }}
        </span>
      </div>

      <div>
        <label class="block text-xs font-medium text-n-slate-11 mb-1.5">
          {{ $t('BRAZIL_WHATSAPP.INSTANCE_NAME_LABEL') }}
        </label>
        <input
          v-model="instanceName"
          type="text"
          :placeholder="$t('BRAZIL_WHATSAPP.INSTANCE_NAME_PLACEHOLDER')"
          class="w-full px-3 py-2 text-sm bg-n-background border border-n-weak rounded-lg focus:outline-none focus:border-n-brand text-n-slate-12"
        />
        <span
          v-if="v$.instanceName.$error"
          class="text-xs text-n-ruby-11 mt-1 block"
        >
          {{ $t('BRAZIL_WHATSAPP.REQUIRED_FIELD') }}
        </span>
      </div>

      <div class="flex items-center gap-2">
        <input
          id="allowGroupsCheckbox"
          v-model="allowGroups"
          type="checkbox"
          class="rounded border-n-weak text-n-brand focus:ring-n-brand"
        />
        <label for="allowGroupsCheckbox" class="text-xs text-n-slate-12">
          {{ $t('BRAZIL_WHATSAPP.ALLOW_GROUPS_LABEL') }}
        </label>
      </div>

      <div class="p-3 rounded-lg bg-n-alpha-1 border border-n-weak">
        <div class="flex items-center justify-between gap-2 mb-1">
          <span class="text-xs font-medium text-n-slate-11">
            {{ $t('BRAZIL_WHATSAPP.WEBHOOK_PREVIEW_LABEL') }}
          </span>
          <NextButton
            type="button"
            xs
            slate
            faded
            icon="i-lucide-copy"
            :label="$t('BRAZIL_WHATSAPP.COPY_WEBHOOK')"
            @click="copyWebhook"
          />
        </div>
        <code class="text-xs text-n-slate-12 break-all block">
          {{ webhookPreviewUrl }}
        </code>
      </div>

      <div class="pt-4 flex items-center gap-3">
        <NextButton
          type="submit"
          :is-loading="uiFlags.isCreating"
          :label="$t('BRAZIL_WHATSAPP.CREATE_BUTTON')"
        />
      </div>
    </form>

    <div v-else class="space-y-5">
      <div
        class="p-4 rounded-xl bg-n-alpha-1 border border-n-weak flex flex-col items-center gap-3"
      >
        <h3 class="text-sm font-semibold text-n-slate-12">
          {{ $t('BRAZIL_WHATSAPP.QR_SECTION_TITLE') }}
        </h3>
        <span
          class="text-xs px-2.5 py-1 rounded-full font-medium"
          :class="
            connectionState === 'open'
              ? 'bg-n-teal-3 text-n-teal-11'
              : 'bg-n-amber-3 text-n-amber-11'
          "
        >
          {{
            connectionState === 'open'
              ? $t('BRAZIL_WHATSAPP.QR_STATUS_OPEN')
              : $t('BRAZIL_WHATSAPP.QR_STATUS_PENDING')
          }}
        </span>

        <img
          v-if="qrDataUrl"
          :src="qrDataUrl"
          alt=""
          class="size-56 rounded-lg border border-n-weak bg-white p-2"
        />

        <div v-if="pairingCode" class="text-center">
          <span class="text-xs text-n-slate-11">
            {{ $t('BRAZIL_WHATSAPP.PAIRING_CODE_LABEL') }}
          </span>
          <strong class="ms-1 text-base font-mono text-n-slate-12">
            {{ pairingCode }}
          </strong>
        </div>

        <div class="flex items-center gap-3 pt-2">
          <NextButton
            type="button"
            slate
            faded
            sm
            icon="i-lucide-refresh-cw"
            :is-loading="isLoadingQr"
            :label="$t('BRAZIL_WHATSAPP.QR_LOAD_BUTTON')"
            @click="loadQrCode"
          />
          <NextButton
            type="button"
            sm
            icon="i-lucide-arrow-right"
            :label="$t('BRAZIL_WHATSAPP.CONTINUE_TO_AGENTS')"
            @click="goToAddAgents"
          />
        </div>
      </div>
    </div>
  </div>
</template>
