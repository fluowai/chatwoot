<script setup>
import { ref, computed, onMounted } from 'vue';
import { useStore } from 'vuex';
import { useRoute, useRouter } from 'vue-router';
import { useI18n } from 'vue-i18n';
import Draggable from 'vuedraggable';
import { useAlert } from 'dashboard/composables';
import { formatBRL, parseBRLInput } from 'shared/helpers/brazilHelpers';
import NextButton from 'dashboard/components-next/button/Button.vue';

const store = useStore();
const route = useRoute();
const router = useRouter();
const { t } = useI18n();

const accountId = computed(() => route.params.accountId);
const isLoading = ref(false);
const isCreatingLabels = ref(false);
const searchQuery = ref('');
const selectedInboxId = ref('all');
const editingValueId = ref(null);
const editingValueInput = ref('');

const stages = computed(() => [
  {
    id: 'lead',
    title: t('KANBAN.STAGE_LEAD'),
    dotClass: 'bg-n-blue-9',
    label: 'lead',
    hex: '#3B82F6',
  },
  {
    id: 'qualificacao',
    title: t('KANBAN.STAGE_QUALIFICATION'),
    dotClass: 'bg-n-amber-9',
    label: 'qualificacao',
    hex: '#F59E0B',
  },
  {
    id: 'negociacao',
    title: t('KANBAN.STAGE_PROPOSAL'),
    dotClass: 'bg-n-iris-9',
    label: 'negociacao',
    hex: '#8B5CF6',
  },
  {
    id: 'ganho',
    title: t('KANBAN.STAGE_WON'),
    dotClass: 'bg-n-teal-9',
    label: 'ganho',
    hex: '#10B981',
  },
  {
    id: 'perdido',
    title: t('KANBAN.STAGE_LOST'),
    dotClass: 'bg-n-ruby-9',
    label: 'perdido',
    hex: '#EF4444',
  },
]);

const STAGE_LABELS = ['lead', 'qualificacao', 'negociacao', 'ganho', 'perdido'];

const allConversations = computed(
  () => store.getters['conversations/getAllConversations'] || []
);

const inboxes = computed(() => store.getters['inboxes/getInboxes'] || []);
const existingLabels = computed(() => store.getters['labels/getLabels'] || []);

const getLabelsForChat = chat => {
  const storeLabels = store.getters['conversationLabels/getConversationLabels'](
    chat.id
  );
  if (Array.isArray(storeLabels) && storeLabels.length > 0) {
    return storeLabels;
  }
  return chat.labels || [];
};

const getDealValue = chat => {
  return Number(chat.custom_attributes?.valor_negocio || 0) || 0;
};

const filteredConversations = computed(() => {
  const query = searchQuery.value.trim().toLowerCase();
  return allConversations.value.filter(chat => {
    if (
      selectedInboxId.value !== 'all' &&
      Number(chat.inbox_id) !== Number(selectedInboxId.value)
    ) {
      return false;
    }
    if (!query) return true;
    const senderName = (chat.meta?.sender?.name || '').toLowerCase();
    const senderPhone = (chat.meta?.sender?.phone_number || '').toLowerCase();
    const idMatch = String(chat.id).includes(query.replace('#', ''));
    return senderName.includes(query) || senderPhone.includes(query) || idMatch;
  });
});

const getStageConversations = stageLabel => {
  if (!stageLabel) {
    return filteredConversations.value.filter(chat => {
      const labels = getLabelsForChat(chat);
      return !labels.some(l => STAGE_LABELS.includes(l));
    });
  }
  return filteredConversations.value.filter(chat => {
    const labels = getLabelsForChat(chat);
    return labels.includes(stageLabel);
  });
};

const getStageTotalBRL = stageLabel => {
  const list = getStageConversations(stageLabel);
  const sum = list.reduce((acc, chat) => acc + getDealValue(chat), 0);
  return formatBRL(sum);
};

const totalPipelineBRL = computed(() => {
  const sum = filteredConversations.value.reduce(
    (acc, chat) => acc + getDealValue(chat),
    0
  );
  return formatBRL(sum);
});

const missingStageLabels = computed(() => {
  const titles = new Set(existingLabels.value.map(l => l.title));
  return stages.value.filter(s => !titles.has(s.label));
});

const setupDefaultLabels = async () => {
  isCreatingLabels.value = true;
  try {
    await Promise.all(
      missingStageLabels.value.map(stage =>
        store.dispatch('labels/create', {
          title: stage.label,
          description: stage.title,
          color: stage.hex,
          show_on_sidebar: true,
        })
      )
    );
    useAlert(t('KANBAN.SETUP_LABELS_SUCCESS'));
  } catch (error) {
    useAlert(error.message);
  } finally {
    isCreatingLabels.value = false;
  }
};

const onCardDropped = async (event, targetStageLabel, stageTitle) => {
  if (!event.added) return;
  const movedChat = event.added.element;
  if (!movedChat) return;

  const currentLabels = getLabelsForChat(movedChat);
  const nonStageLabels = currentLabels.filter(l => !STAGE_LABELS.includes(l));
  const updatedLabels = targetStageLabel
    ? [...nonStageLabels, targetStageLabel]
    : nonStageLabels;

  movedChat.labels = updatedLabels;
  await store.dispatch('conversationLabels/update', {
    conversationId: movedChat.id,
    labels: updatedLabels,
  });
  useAlert(t('KANBAN.STAGE_MOVED_SUCCESS', { stage: stageTitle }));
};

const startEditingValue = chat => {
  editingValueId.value = chat.id;
  const val = getDealValue(chat);
  editingValueInput.value = val > 0 ? val.toFixed(2).replace('.', ',') : '';
};

const cancelEditingValue = () => {
  editingValueId.value = null;
  editingValueInput.value = '';
};

const saveDealValue = async chat => {
  const numericValue = parseBRLInput(editingValueInput.value);
  const updatedAttrs = {
    ...(chat.custom_attributes || {}),
    valor_negocio: numericValue,
  };
  await store.dispatch('conversations/updateCustomAttributes', {
    conversationId: chat.id,
    customAttributes: updatedAttrs,
  });
  editingValueId.value = null;
  useAlert(t('KANBAN.VALUE_SAVED_SUCCESS'));
};

const openConversation = conversationId => {
  router.push({
    name: 'inbox_conversation',
    params: {
      accountId: accountId.value,
      conversation_id: conversationId,
    },
  });
};

const refreshBoard = async () => {
  isLoading.value = true;
  try {
    await Promise.all([
      store.dispatch('conversations/fetchAllConversations'),
      store.dispatch('labels/get'),
      store.dispatch('inboxes/get'),
    ]);
  } catch {
    // store handles error notifications
  } finally {
    isLoading.value = false;
  }
};

onMounted(() => {
  refreshBoard();
});
</script>

<template>
  <div
    class="flex flex-col h-full w-full bg-n-background dark:bg-n-solid-1 overflow-hidden"
  >
    <header
      class="flex flex-wrap items-center justify-between gap-4 px-6 py-4 border-b border-n-weak"
    >
      <div class="flex items-center gap-3">
        <div class="p-2 rounded-lg bg-n-brand/10 text-n-brand">
          <span class="i-lucide-kanban text-xl block" />
        </div>
        <div>
          <h1 class="text-lg font-semibold text-n-slate-12">
            {{ $t('KANBAN.TITLE') }}
          </h1>
          <p class="text-xs text-n-slate-11">
            {{ $t('KANBAN.SUBTITLE') }}
          </p>
        </div>
      </div>

      <div class="flex flex-wrap items-center gap-3">
        <div
          class="px-3 py-1.5 rounded-lg bg-n-teal-3/60 border border-n-teal-6 text-xs text-n-teal-11 font-medium"
        >
          {{ $t('KANBAN.TOTAL_PIPELINE') }}
          <strong class="ms-1 font-semibold">{{ totalPipelineBRL }}</strong>
        </div>

        <input
          v-model="searchQuery"
          type="text"
          :placeholder="$t('KANBAN.SEARCH_PLACEHOLDER')"
          class="px-3 py-1.5 text-xs bg-n-solid-1 border border-n-weak rounded-lg focus:outline-none focus:border-n-brand text-n-slate-12 w-52"
        />

        <select
          v-model="selectedInboxId"
          class="px-3 py-1.5 text-xs bg-n-solid-1 border border-n-weak rounded-lg focus:outline-none focus:border-n-brand text-n-slate-12"
        >
          <option value="all">{{ $t('KANBAN.ALL_INBOXES') }}</option>
          <option v-for="inbox in inboxes" :key="inbox.id" :value="inbox.id">
            {{ inbox.name }}
          </option>
        </select>

        <NextButton
          v-if="missingStageLabels.length > 0"
          type="button"
          sm
          slate
          faded
          icon="i-lucide-tags"
          :is-loading="isCreatingLabels"
          :label="$t('KANBAN.SETUP_LABELS_BTN')"
          @click="setupDefaultLabels"
        />

        <NextButton
          type="button"
          sm
          slate
          faded
          icon="i-lucide-refresh-cw"
          :is-loading="isLoading"
          :label="$t('KANBAN.REFRESH_BTN')"
          @click="refreshBoard"
        />
      </div>
    </header>

    <div class="flex-1 overflow-x-auto p-5 flex gap-4 items-start">
      <!-- Triage / Unassigned Column -->
      <div
        class="w-80 shrink-0 flex flex-col max-h-full rounded-xl bg-n-alpha-1 border border-n-weak"
      >
        <div
          class="flex items-center justify-between px-4 py-3 border-b border-n-weak"
        >
          <div class="flex items-center gap-2">
            <span class="size-2.5 rounded-full bg-n-slate-9" />
            <span class="font-medium text-sm text-n-slate-12">
              {{ $t('KANBAN.STAGE_UNASSIGNED') }}
            </span>
          </div>
          <div class="flex items-center gap-2">
            <span class="text-[11px] font-medium text-n-slate-11">
              {{ getStageTotalBRL(null) }}
            </span>
            <span
              class="text-xs px-2 py-0.5 rounded-full bg-n-weak text-n-slate-11"
            >
              {{ getStageConversations(null).length }}
            </span>
          </div>
        </div>

        <Draggable
          :model-value="getStageConversations(null)"
          group="kanban-deals"
          item-key="id"
          class="flex-1 overflow-y-auto p-3 space-y-3 min-h-[8rem]"
          @change="e => onCardDropped(e, null, $t('KANBAN.STAGE_UNASSIGNED'))"
        >
          <template #item="{ element: chat }">
            <div
              class="p-3.5 bg-n-solid-1 rounded-lg border border-n-weak hover:border-n-brand cursor-grab active:cursor-grabbing shadow-sm transition-all"
            >
              <div class="flex items-center justify-between mb-1.5">
                <button
                  type="button"
                  class="text-xs font-semibold text-n-slate-12 hover:text-n-brand truncate max-w-[11rem] text-start"
                  @click="openConversation(chat.id)"
                >
                  {{ chat.meta?.sender?.name || $t('KANBAN.DEFAULT_CUSTOMER') }}
                </button>
                <span class="text-[10px] text-n-slate-10">
                  {{ `#${chat.id}` }}
                </span>
              </div>

              <p class="text-xs text-n-slate-11 line-clamp-2 mb-2">
                {{
                  chat.messages?.[chat.messages.length - 1]?.content ||
                  $t('KANBAN.NO_MESSAGES')
                }}
              </p>

              <div
                v-if="editingValueId === chat.id"
                class="flex items-center gap-1.5 mb-2"
              >
                <input
                  v-model="editingValueInput"
                  type="text"
                  :placeholder="$t('KANBAN.VALUE_PLACEHOLDER')"
                  class="w-full px-2 py-1 text-xs bg-n-background border border-n-weak rounded text-n-slate-12"
                  @keyup.enter="saveDealValue(chat)"
                />
                <NextButton
                  type="button"
                  xs
                  :label="$t('KANBAN.SAVE_VALUE')"
                  @click="saveDealValue(chat)"
                />
                <NextButton
                  type="button"
                  xs
                  slate
                  faded
                  :label="$t('KANBAN.CANCEL')"
                  @click="cancelEditingValue"
                />
              </div>
              <div v-else class="flex items-center justify-between mb-2">
                <button
                  type="button"
                  :title="$t('KANBAN.EDIT_VALUE_TITLE')"
                  class="text-xs font-semibold px-2 py-0.5 rounded bg-n-teal-3/60 text-n-teal-11 hover:bg-n-teal-4/60"
                  @click="startEditingValue(chat)"
                >
                  {{ formatBRL(getDealValue(chat)) }}
                </button>
                <button
                  type="button"
                  class="text-[11px] text-n-brand hover:underline"
                  @click="openConversation(chat.id)"
                >
                  {{ $t('KANBAN.OPEN_CHAT') }}
                </button>
              </div>

              <div
                class="flex items-center justify-between text-[11px] text-n-slate-10 pt-2 border-t border-n-weak/50"
              >
                <span class="truncate max-w-[7rem]">
                  {{ chat.meta?.sender?.phone_number || chat.meta?.channel }}
                </span>
                <span class="truncate max-w-[7rem]">
                  {{
                    chat.meta?.assignee?.name || $t('KANBAN.UNASSIGNED_AGENT')
                  }}
                </span>
              </div>
            </div>
          </template>
        </Draggable>
      </div>

      <!-- Funnel Stage Columns -->
      <div
        v-for="col in stages"
        :key="col.id"
        class="w-80 shrink-0 flex flex-col max-h-full rounded-xl bg-n-alpha-1 border border-n-weak"
      >
        <div
          class="flex items-center justify-between px-4 py-3 border-b border-n-weak"
        >
          <div class="flex items-center gap-2">
            <span class="size-2.5 rounded-full" :class="col.dotClass" />
            <span class="font-medium text-sm text-n-slate-12">
              {{ col.title }}
            </span>
          </div>
          <div class="flex items-center gap-2">
            <span class="text-[11px] font-medium text-n-slate-11">
              {{ getStageTotalBRL(col.label) }}
            </span>
            <span
              class="text-xs px-2 py-0.5 rounded-full bg-n-weak text-n-slate-11"
            >
              {{ getStageConversations(col.label).length }}
            </span>
          </div>
        </div>

        <Draggable
          :model-value="getStageConversations(col.label)"
          group="kanban-deals"
          item-key="id"
          class="flex-1 overflow-y-auto p-3 space-y-3 min-h-[8rem]"
          @change="e => onCardDropped(e, col.label, col.title)"
        >
          <template #item="{ element: chat }">
            <div
              class="p-3.5 bg-n-solid-1 rounded-lg border border-n-weak hover:border-n-brand cursor-grab active:cursor-grabbing shadow-sm transition-all"
            >
              <div class="flex items-center justify-between mb-1.5">
                <button
                  type="button"
                  class="text-xs font-semibold text-n-slate-12 hover:text-n-brand truncate max-w-[11rem] text-start"
                  @click="openConversation(chat.id)"
                >
                  {{ chat.meta?.sender?.name || $t('KANBAN.DEFAULT_CUSTOMER') }}
                </button>
                <span class="text-[10px] text-n-slate-10">
                  {{ `#${chat.id}` }}
                </span>
              </div>

              <p class="text-xs text-n-slate-11 line-clamp-2 mb-2">
                {{
                  chat.messages?.[chat.messages.length - 1]?.content ||
                  $t('KANBAN.NO_MESSAGES')
                }}
              </p>

              <div
                v-if="editingValueId === chat.id"
                class="flex items-center gap-1.5 mb-2"
              >
                <input
                  v-model="editingValueInput"
                  type="text"
                  :placeholder="$t('KANBAN.VALUE_PLACEHOLDER')"
                  class="w-full px-2 py-1 text-xs bg-n-background border border-n-weak rounded text-n-slate-12"
                  @keyup.enter="saveDealValue(chat)"
                />
                <NextButton
                  type="button"
                  xs
                  :label="$t('KANBAN.SAVE_VALUE')"
                  @click="saveDealValue(chat)"
                />
                <NextButton
                  type="button"
                  xs
                  slate
                  faded
                  :label="$t('KANBAN.CANCEL')"
                  @click="cancelEditingValue"
                />
              </div>
              <div v-else class="flex items-center justify-between mb-2">
                <button
                  type="button"
                  :title="$t('KANBAN.EDIT_VALUE_TITLE')"
                  class="text-xs font-semibold px-2 py-0.5 rounded bg-n-teal-3/60 text-n-teal-11 hover:bg-n-teal-4/60"
                  @click="startEditingValue(chat)"
                >
                  {{ formatBRL(getDealValue(chat)) }}
                </button>
                <button
                  type="button"
                  class="text-[11px] text-n-brand hover:underline"
                  @click="openConversation(chat.id)"
                >
                  {{ $t('KANBAN.OPEN_CHAT') }}
                </button>
              </div>

              <div
                class="flex items-center justify-between text-[11px] text-n-slate-10 pt-2 border-t border-n-weak/50"
              >
                <span class="truncate max-w-[7rem]">
                  {{ chat.meta?.sender?.phone_number || chat.meta?.channel }}
                </span>
                <span class="truncate max-w-[7rem]">
                  {{
                    chat.meta?.assignee?.name || $t('KANBAN.UNASSIGNED_AGENT')
                  }}
                </span>
              </div>
            </div>
          </template>
        </Draggable>
      </div>
    </div>
  </div>
</template>
