<script setup>
import { ref, computed, onMounted } from 'vue';
import { useStore } from 'vuex';
import { useRoute, useRouter } from 'vue-router';
import { useI18n } from 'vue-i18n';

const store = useStore();
const route = useRoute();
const router = useRouter();
const { t } = useI18n();

const accountId = computed(() => route.params.accountId);
const isLoading = ref(true);

const columns = ref([
  { id: 'lead', title: 'Novo Lead', color: '#3B82F6', label: 'lead' },
  { id: 'qualificacao', title: 'Qualificação', color: '#F59E0B', label: 'qualificacao' },
  { id: 'negociacao', title: 'Proposta / Negociação', color: '#8B5CF6', label: 'negociacao' },
  { id: 'ganho', title: 'Fechado / Ganho', color: '#10B981', label: 'ganho' },
  { id: 'perdido', title: 'Perdido', color: '#EF4444', label: 'perdido' },
]);

const allConversations = computed(() => {
  return store.getters['conversations/getAllConversations'] || [];
});

const getColumnConversations = label => {
  return allConversations.value.filter(conv => {
    const labels = conv.labels || [];
    return labels.includes(label);
  });
};

const unassignedConversations = computed(() => {
  const columnLabels = columns.value.map(c => c.label);
  return allConversations.value.filter(conv => {
    const labels = conv.labels || [];
    return !labels.some(l => columnLabels.includes(l));
  });
});

const openConversation = conversationId => {
  router.push({
    name: 'inbox_conversation',
    params: {
      accountId: accountId.value,
      conversation_id: conversationId,
    },
  });
};

onMounted(async () => {
  try {
    await store.dispatch('conversations/fetchAllConversations');
  } catch (error) {
    // handled by store
  } finally {
    isLoading.value = false;
  }
});
</script>

<template>
  <div class="flex flex-col h-full bg-n-background dark:bg-n-solid-1 overflow-hidden">
    <!-- Header -->
    <header class="flex items-center justify-between px-6 py-4 border-b border-n-weak">
      <div class="flex items-center gap-3">
        <div class="p-2 rounded-lg bg-n-brand/10 text-n-brand">
          <span class="i-lucide-kanban text-xl" />
        </div>
        <div>
          <h1 class="text-xl font-semibold text-n-slate-12">Funil de Vendas (Kanban CRM)</h1>
          <p class="text-xs text-n-slate-11">Gerencie leads e negociações organizados por estágios</p>
        </div>
      </div>
    </header>

    <!-- Kanban Board Columns -->
    <div class="flex-1 overflow-x-auto p-6 flex gap-5 items-start">
      <!-- Unassigned / Inbox Triagem Column -->
      <div class="w-80 shrink-0 flex flex-col max-h-full rounded-xl bg-n-alpha-1 border border-n-weak">
        <div class="flex items-center justify-between px-4 py-3 border-b border-n-weak">
          <div class="flex items-center gap-2">
            <span class="size-2.5 rounded-full bg-n-slate-9" />
            <span class="font-medium text-sm text-n-slate-12">Sem Etapa / Entrada</span>
          </div>
          <span class="text-xs px-2 py-0.5 rounded-full bg-n-weak text-n-slate-11">
            {{ unassignedConversations.length }}
          </span>
        </div>
        <div class="flex-1 overflow-y-auto p-3 space-y-3">
          <div
            v-for="chat in unassignedConversations"
            :key="chat.id"
            class="p-3.5 bg-n-solid-1 rounded-lg border border-n-weak hover:border-n-brand cursor-pointer shadow-sm transition-all"
            @click="openConversation(chat.id)"
          >
            <div class="flex items-center justify-between mb-2">
              <span class="text-xs font-semibold text-n-slate-12 truncate max-w-[180px]">
                {{ chat.meta?.sender?.name || 'Cliente' }}
              </span>
              <span class="text-[10px] text-n-slate-10">
                #{{ chat.id }}
              </span>
            </div>
            <p class="text-xs text-n-slate-11 line-clamp-2 mb-2">
              {{ chat.messages?.[chat.messages.length - 1]?.content || 'Sem mensagens' }}
            </p>
            <div class="flex items-center justify-between text-[11px] text-n-slate-10 pt-2 border-t border-n-weak/50">
              <span>{{ chat.meta?.channel }}</span>
              <span>{{ chat.meta?.assignee?.name || 'Não atribuído' }}</span>
            </div>
          </div>
        </div>
      </div>

      <!-- Configured Stage Columns -->
      <div
        v-for="col in columns"
        :key="col.id"
        class="w-80 shrink-0 flex flex-col max-h-full rounded-xl bg-n-alpha-1 border border-n-weak"
      >
        <div class="flex items-center justify-between px-4 py-3 border-b border-n-weak">
          <div class="flex items-center gap-2">
            <span class="size-2.5 rounded-full" :style="{ backgroundColor: col.color }" />
            <span class="font-medium text-sm text-n-slate-12">{{ col.title }}</span>
          </div>
          <span class="text-xs px-2 py-0.5 rounded-full bg-n-weak text-n-slate-11">
            {{ getColumnConversations(col.label).length }}
          </span>
        </div>
        <div class="flex-1 overflow-y-auto p-3 space-y-3">
          <div
            v-for="chat in getColumnConversations(col.label)"
            :key="chat.id"
            class="p-3.5 bg-n-solid-1 rounded-lg border border-n-weak hover:border-n-brand cursor-pointer shadow-sm transition-all"
            @click="openConversation(chat.id)"
          >
            <div class="flex items-center justify-between mb-2">
              <span class="text-xs font-semibold text-n-slate-12 truncate max-w-[180px]">
                {{ chat.meta?.sender?.name || 'Cliente' }}
              </span>
              <span class="text-[10px] text-n-slate-10">
                #{{ chat.id }}
              </span>
            </div>
            <p class="text-xs text-n-slate-11 line-clamp-2 mb-2">
              {{ chat.messages?.[chat.messages.length - 1]?.content || 'Sem mensagens' }}
            </p>
            <div class="flex items-center justify-between text-[11px] text-n-slate-10 pt-2 border-t border-n-weak/50">
              <span>{{ chat.meta?.channel }}</span>
              <span>{{ chat.meta?.assignee?.name || 'Não atribuído' }}</span>
            </div>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

