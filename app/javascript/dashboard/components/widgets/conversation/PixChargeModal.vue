<script setup>
import { ref, watch, onMounted } from 'vue';
import { useI18n } from 'vue-i18n';
import QRCode from 'qrcode';
import { useAlert } from 'dashboard/composables';
import { copyTextToClipboard } from 'shared/helpers/clipboard';
import { buildPixChatMessage } from 'shared/helpers/brazilHelpers';
import NextButton from 'dashboard/components-next/button/Button.vue';

const props = defineProps({
  show: {
    type: Boolean,
    default: false,
  },
  accountName: {
    type: String,
    default: '',
  },
});

const emit = defineEmits(['close', 'insertMessage', 'sendPixWithQr']);

const { t } = useI18n();

const STORAGE_KEY = 'cw_brazil_pix_defaults';

const keyType = ref('cpf_cnpj');
const pixKey = ref('');
const merchantName = ref('');
const merchantCity = ref('SAO PAULO');
const amount = ref('');
const description = ref('');
const txid = ref('***');

const generatedPayload = ref('');
const generatedMessage = ref('');
const qrCodeDataUrl = ref('');

const loadDefaults = () => {
  const globalCfg = window.globalConfig || {};
  let saved = {};
  try {
    saved = JSON.parse(window.localStorage.getItem(STORAGE_KEY) || '{}');
  } catch {
    saved = {};
  }
  pixKey.value = saved.pixKey || globalCfg.PIX_DEFAULT_KEY || '';
  merchantName.value =
    saved.merchantName ||
    globalCfg.PIX_MERCHANT_NAME ||
    props.accountName ||
    '';
  merchantCity.value =
    saved.merchantCity || globalCfg.PIX_MERCHANT_CITY || 'SAO PAULO';
  if (saved.keyType) keyType.value = saved.keyType;
};

const saveDefaults = () => {
  try {
    window.localStorage.setItem(
      STORAGE_KEY,
      JSON.stringify({
        keyType: keyType.value,
        pixKey: pixKey.value,
        merchantName: merchantName.value,
        merchantCity: merchantCity.value,
      })
    );
  } catch {
    // ignore storage quota errors
  }
};

const generatePreview = async () => {
  if (!pixKey.value.trim() || !merchantName.value.trim()) {
    useAlert(t('PIX_MODAL.INVALID_FIELDS'));
    return false;
  }

  try {
    saveDefaults();
    const { payload, message } = buildPixChatMessage({
      key: pixKey.value,
      name: merchantName.value,
      city: merchantCity.value,
      amount: amount.value,
      txid: txid.value || '***',
      keyType: keyType.value,
      description: description.value,
    });
    generatedPayload.value = payload;
    generatedMessage.value = message;
    qrCodeDataUrl.value = await QRCode.toDataURL(payload, {
      width: 260,
      margin: 2,
    });
    return true;
  } catch (error) {
    useAlert(error.message || t('PIX_MODAL.INVALID_FIELDS'));
    return false;
  }
};

const copyPayload = async () => {
  if (!generatedPayload.value) return;
  await copyTextToClipboard(generatedPayload.value);
  useAlert(t('PIX_MODAL.COPIED_SUCCESS'));
};

const handleInsertInEditor = async () => {
  if (!generatedMessage.value) {
    const ok = await generatePreview();
    if (!ok) return;
  }
  emit('insertMessage', generatedMessage.value);
  emit('close');
};

const dataUrlToFile = (dataUrl, fileName) => {
  const [header, base64] = dataUrl.split(',');
  const mimeMatch = header.match(/:(.*?);/);
  const mime = mimeMatch ? mimeMatch[1] : 'image/png';
  const binary = window.atob(base64);
  const array = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i += 1) {
    array[i] = binary.charCodeAt(i);
  }
  return new File([array], fileName, { type: mime });
};

const handleSendWithQr = async () => {
  if (!generatedPayload.value || !qrCodeDataUrl.value) {
    const ok = await generatePreview();
    if (!ok) return;
  }
  const qrFile = dataUrlToFile(qrCodeDataUrl.value, `pix_${Date.now()}.png`);
  emit('sendPixWithQr', {
    message: generatedMessage.value,
    qrFile,
  });
  emit('close');
};

watch(
  () => props.show,
  isOpen => {
    if (isOpen) {
      loadDefaults();
      generatedPayload.value = '';
      generatedMessage.value = '';
      qrCodeDataUrl.value = '';
    }
  }
);

onMounted(() => {
  loadDefaults();
});
</script>

<template>
  <Teleport to="body">
    <div
      v-if="props.show"
      class="fixed inset-0 z-50 flex items-center justify-center bg-modal-backdrop-light dark:bg-modal-backdrop-dark p-4"
    >
      <div
        class="w-full max-w-lg rounded-2xl bg-n-solid-1 border border-n-weak shadow-xl overflow-hidden max-h-[90vh] flex flex-col"
      >
        <div
          class="flex items-center justify-between px-6 py-4 border-b border-n-weak"
        >
          <div>
            <h3 class="text-base font-semibold text-n-slate-12">
              {{ $t('PIX_MODAL.TITLE') }}
            </h3>
            <p class="text-xs text-n-slate-11 mt-0.5">
              {{ $t('PIX_MODAL.SUBTITLE') }}
            </p>
          </div>
          <NextButton
            type="button"
            xs
            slate
            ghost
            icon="i-lucide-x"
            @click="emit('close')"
          />
        </div>

        <div class="p-6 overflow-y-auto space-y-4">
          <div class="grid grid-cols-2 gap-3">
            <div>
              <label class="block text-xs font-medium text-n-slate-11 mb-1">
                {{ $t('PIX_MODAL.KEY_TYPE_LABEL') }}
              </label>
              <select
                v-model="keyType"
                class="w-full px-3 py-2 text-xs bg-n-background border border-n-weak rounded-lg text-n-slate-12"
              >
                <option value="cpf_cnpj">
                  {{ $t('PIX_MODAL.KEY_TYPE_CPF_CNPJ') }}
                </option>
                <option value="email">
                  {{ $t('PIX_MODAL.KEY_TYPE_EMAIL') }}
                </option>
                <option value="phone">
                  {{ $t('PIX_MODAL.KEY_TYPE_PHONE') }}
                </option>
                <option value="evp">
                  {{ $t('PIX_MODAL.KEY_TYPE_EVP') }}
                </option>
              </select>
            </div>

            <div>
              <label class="block text-xs font-medium text-n-slate-11 mb-1">
                {{ $t('PIX_MODAL.AMOUNT_LABEL') }}
              </label>
              <input
                v-model="amount"
                type="text"
                :placeholder="$t('PIX_MODAL.AMOUNT_PLACEHOLDER')"
                class="w-full px-3 py-2 text-xs bg-n-background border border-n-weak rounded-lg text-n-slate-12"
              />
            </div>
          </div>

          <div>
            <label class="block text-xs font-medium text-n-slate-11 mb-1">
              {{ $t('PIX_MODAL.KEY_LABEL') }}
            </label>
            <input
              v-model="pixKey"
              type="text"
              :placeholder="$t('PIX_MODAL.KEY_PLACEHOLDER')"
              class="w-full px-3 py-2 text-xs bg-n-background border border-n-weak rounded-lg text-n-slate-12"
            />
          </div>

          <div class="grid grid-cols-2 gap-3">
            <div>
              <label class="block text-xs font-medium text-n-slate-11 mb-1">
                {{ $t('PIX_MODAL.MERCHANT_NAME_LABEL') }}
              </label>
              <input
                v-model="merchantName"
                type="text"
                maxlength="25"
                :placeholder="$t('PIX_MODAL.MERCHANT_NAME_PLACEHOLDER')"
                class="w-full px-3 py-2 text-xs bg-n-background border border-n-weak rounded-lg text-n-slate-12"
              />
            </div>

            <div>
              <label class="block text-xs font-medium text-n-slate-11 mb-1">
                {{ $t('PIX_MODAL.MERCHANT_CITY_LABEL') }}
              </label>
              <input
                v-model="merchantCity"
                type="text"
                maxlength="15"
                :placeholder="$t('PIX_MODAL.MERCHANT_CITY_PLACEHOLDER')"
                class="w-full px-3 py-2 text-xs bg-n-background border border-n-weak rounded-lg text-n-slate-12"
              />
            </div>
          </div>

          <div class="grid grid-cols-2 gap-3">
            <div>
              <label class="block text-xs font-medium text-n-slate-11 mb-1">
                {{ $t('PIX_MODAL.DESCRIPTION_LABEL') }}
              </label>
              <input
                v-model="description"
                type="text"
                maxlength="40"
                :placeholder="$t('PIX_MODAL.DESCRIPTION_PLACEHOLDER')"
                class="w-full px-3 py-2 text-xs bg-n-background border border-n-weak rounded-lg text-n-slate-12"
              />
            </div>

            <div>
              <label class="block text-xs font-medium text-n-slate-11 mb-1">
                {{ $t('PIX_MODAL.TXID_LABEL') }}
              </label>
              <input
                v-model="txid"
                type="text"
                maxlength="25"
                :placeholder="$t('PIX_MODAL.TXID_PLACEHOLDER')"
                class="w-full px-3 py-2 text-xs bg-n-background border border-n-weak rounded-lg text-n-slate-12"
              />
            </div>
          </div>

          <div>
            <NextButton
              type="button"
              sm
              slate
              faded
              icon="i-lucide-qr-code"
              :label="$t('PIX_MODAL.GENERATE_PREVIEW')"
              @click="generatePreview"
            />
          </div>

          <div
            v-if="generatedPayload"
            class="p-4 rounded-xl bg-n-alpha-1 border border-n-weak space-y-3"
          >
            <div class="flex justify-center">
              <img
                v-if="qrCodeDataUrl"
                :src="qrCodeDataUrl"
                alt=""
                class="size-44 rounded-lg border border-n-weak bg-white p-1.5"
              />
            </div>

            <div>
              <div class="flex items-center justify-between mb-1">
                <span class="text-xs font-medium text-n-slate-11">
                  {{ $t('PIX_MODAL.COPIA_E_COLA_LABEL') }}
                </span>
                <NextButton
                  type="button"
                  xs
                  slate
                  faded
                  icon="i-lucide-copy"
                  :label="$t('PIX_MODAL.COPY_CODE')"
                  @click="copyPayload"
                />
              </div>
              <textarea
                :value="generatedPayload"
                readonly
                rows="2"
                class="w-full p-2 text-[11px] font-mono bg-n-background border border-n-weak rounded-lg text-n-slate-12 resize-none"
              />
            </div>
          </div>
        </div>

        <div
          class="flex flex-wrap items-center justify-end gap-2 px-6 py-4 border-t border-n-weak bg-n-alpha-1"
        >
          <NextButton
            type="button"
            sm
            slate
            faded
            :label="$t('PIX_MODAL.CLOSE')"
            @click="emit('close')"
          />
          <NextButton
            type="button"
            sm
            slate
            :label="$t('PIX_MODAL.INSERT_IN_EDITOR')"
            @click="handleInsertInEditor"
          />
          <NextButton
            type="button"
            sm
            icon="i-lucide-send"
            :label="$t('PIX_MODAL.SEND_WITH_QR')"
            @click="handleSendWithQr"
          />
        </div>
      </div>
    </div>
  </Teleport>
</template>
