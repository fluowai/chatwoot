<script setup>
import { ref, computed } from 'vue';
import { useStore } from 'vuex';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import {
  cleanDigits,
  isValidCPF,
  isValidCNPJ,
  formatCpfCnpj,
  formatCEP,
} from 'shared/helpers/brazilHelpers';
import BrazilToolsAPI from 'dashboard/api/brazilTools';
import NextButton from 'dashboard/components-next/button/Button.vue';

const props = defineProps({
  show: {
    type: Boolean,
    default: false,
  },
  contact: {
    type: Object,
    default: () => ({}),
  },
});

const emit = defineEmits(['close', 'insertMessage']);

const store = useStore();
const { t } = useI18n();

const documentInput = ref('');
const cepInput = ref('');
const isSearchingCep = ref(false);
const cepResult = ref(null);
const cepError = ref('');

const docDigits = computed(() => cleanDigits(documentInput.value));

const docValidation = computed(() => {
  if (!docDigits.value) return null;
  if (docDigits.value.length === 11 && isValidCPF(docDigits.value)) {
    return {
      valid: true,
      type: 'CPF',
      formatted: formatCpfCnpj(docDigits.value),
    };
  }
  if (docDigits.value.length === 14 && isValidCNPJ(docDigits.value)) {
    return {
      valid: true,
      type: 'CNPJ',
      formatted: formatCpfCnpj(docDigits.value),
    };
  }
  return { valid: false };
});

const onCepInput = event => {
  cepInput.value = formatCEP(event.target.value);
};

const searchCep = async () => {
  const digits = cleanDigits(cepInput.value);
  if (digits.length !== 8) {
    cepError.value = t('BRAZIL_TOOLS.CEP_NOT_FOUND');
    cepResult.value = null;
    return;
  }

  isSearchingCep.value = true;
  cepError.value = '';
  try {
    const { data } = await BrazilToolsAPI.lookupCep(digits);
    cepResult.value = data;
  } catch {
    cepResult.value = null;
    cepError.value = t('BRAZIL_TOOLS.CEP_NOT_FOUND');
  } finally {
    isSearchingCep.value = false;
  }
};

const formattedAddressText = computed(() => {
  if (!cepResult.value) return '';
  const { street, neighborhood, city, state, cep } = cepResult.value;
  return [street, neighborhood, `${city} - ${state}`, `CEP: ${cep}`]
    .filter(Boolean)
    .join(', ');
});

const insertDocInChat = () => {
  if (!docValidation.value?.valid) return;
  emit(
    'insertMessage',
    `${docValidation.value.type}: ${docValidation.value.formatted}`
  );
  emit('close');
};

const insertAddressInChat = () => {
  if (!formattedAddressText.value) return;
  emit('insertMessage', formattedAddressText.value);
  emit('close');
};

const saveToContact = async () => {
  if (!props.contact?.id) return;
  const customAttributes = { ...(props.contact.custom_attributes || {}) };
  if (docValidation.value?.valid) {
    customAttributes.cpf_cnpj = docValidation.value.formatted;
  }
  if (cepResult.value) {
    customAttributes.cep = cepResult.value.cep;
    customAttributes.endereco = formattedAddressText.value;
  }

  try {
    await store.dispatch('contacts/update', {
      id: props.contact.id,
      custom_attributes: customAttributes,
    });
    useAlert(t('BRAZIL_TOOLS.CONTACT_UPDATED'));
  } catch (error) {
    useAlert(error.message);
  }
};
</script>

<template>
  <Teleport to="body">
    <div
      v-if="props.show"
      class="fixed inset-0 z-50 flex items-center justify-center bg-modal-backdrop-light dark:bg-modal-backdrop-dark p-4"
    >
      <div
        class="w-full max-w-lg rounded-2xl bg-n-solid-1 border border-n-weak shadow-xl overflow-hidden"
      >
        <div
          class="flex items-center justify-between px-6 py-4 border-b border-n-weak"
        >
          <div>
            <h3 class="text-base font-semibold text-n-slate-12">
              {{ $t('BRAZIL_TOOLS.TITLE') }}
            </h3>
            <p class="text-xs text-n-slate-11 mt-0.5">
              {{ $t('BRAZIL_TOOLS.SUBTITLE') }}
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

        <div class="p-6 space-y-5">
          <!-- CPF / CNPJ Section -->
          <div class="space-y-2">
            <label class="block text-xs font-semibold text-n-slate-12">
              {{ $t('BRAZIL_TOOLS.DOC_SECTION') }}
            </label>
            <input
              v-model="documentInput"
              type="text"
              :placeholder="$t('BRAZIL_TOOLS.DOC_PLACEHOLDER')"
              class="w-full px-3 py-2 text-xs bg-n-background border border-n-weak rounded-lg text-n-slate-12"
            />
            <div v-if="docValidation" class="flex items-center justify-between">
              <span
                class="text-xs font-medium"
                :class="
                  docValidation.valid ? 'text-n-teal-11' : 'text-n-ruby-11'
                "
              >
                {{
                  docValidation.valid
                    ? $t('BRAZIL_TOOLS.DOC_VALID', {
                        type: docValidation.type,
                        formatted: docValidation.formatted,
                      })
                    : $t('BRAZIL_TOOLS.DOC_INVALID')
                }}
              </span>
              <div v-if="docValidation.valid" class="flex items-center gap-2">
                <NextButton
                  type="button"
                  xs
                  slate
                  faded
                  :label="$t('BRAZIL_TOOLS.INSERT_DOC')"
                  @click="insertDocInChat"
                />
              </div>
            </div>
          </div>

          <!-- ViaCEP Section -->
          <div class="space-y-2 pt-3 border-t border-n-weak">
            <label class="block text-xs font-semibold text-n-slate-12">
              {{ $t('BRAZIL_TOOLS.CEP_SECTION') }}
            </label>
            <div class="flex items-center gap-2">
              <input
                :value="cepInput"
                type="text"
                maxlength="9"
                :placeholder="$t('BRAZIL_TOOLS.CEP_PLACEHOLDER')"
                class="flex-1 px-3 py-2 text-xs bg-n-background border border-n-weak rounded-lg text-n-slate-12"
                @input="onCepInput"
                @keyup.enter="searchCep"
              />
              <NextButton
                type="button"
                sm
                :is-loading="isSearchingCep"
                :label="$t('BRAZIL_TOOLS.SEARCH_CEP')"
                @click="searchCep"
              />
            </div>

            <p v-if="cepError" class="text-xs text-n-ruby-11">
              {{ cepError }}
            </p>

            <div
              v-if="cepResult"
              class="p-3 rounded-lg bg-n-alpha-1 border border-n-weak space-y-2"
            >
              <p class="text-xs text-n-slate-12">
                {{ formattedAddressText }}
              </p>
              <NextButton
                type="button"
                xs
                slate
                faded
                :label="$t('BRAZIL_TOOLS.INSERT_ADDRESS')"
                @click="insertAddressInChat"
              />
            </div>
          </div>
        </div>

        <div
          class="flex items-center justify-end gap-2 px-6 py-4 border-t border-n-weak bg-n-alpha-1"
        >
          <NextButton
            v-if="props.contact?.id && (docValidation?.valid || cepResult)"
            type="button"
            sm
            slate
            icon="i-lucide-user-check"
            :label="$t('BRAZIL_TOOLS.SAVE_TO_CONTACT')"
            @click="saveToContact"
          />
          <NextButton
            type="button"
            sm
            slate
            faded
            :label="$t('BRAZIL_TOOLS.CLOSE')"
            @click="emit('close')"
          />
        </div>
      </div>
    </div>
  </Teleport>
</template>
