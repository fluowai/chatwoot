# Roteiro de Verificação e Status de Entrega (VERIFY)

## Checklist das Funcionalidades Entregues

### 1. Desbloqueio Enterprise Perpétuo
- [x] `ChatwootHub.pricing_plan` retorna `'enterprise'`.
- [x] `ChatwootHub.pricing_plan_quantity` retorna `999_999` (sem limite de licenças/agentes).
- [x] `subscription_status` configurado com valor padrão `'active'`.
- [x] Proteção anti-downgrade no job `Enterprise::Internal::CheckNewVersionsJob`.
- [x] Paywalls anulados em `usePolicy.js` (`shouldShowPaywall` retorna `false`, `hasPremiumEnterprise` é `true`).
- [x] Super Admin com toggles premium liberados em `account_features_field/_form.html.erb`.
- [x] `config/features.yml` configurado com flags Enterprise ativadas por padrão para novas contas.
- [x] Tarefa Rake `chatwoot:enterprise:unlock_all` disponível para habilitar todas as contas existentes e atualizar `ACCOUNT_LEVEL_FEATURE_DEFAULTS`.

### 2. WhatsApp Não Oficial
- [x] Provedores adicionados: `evolution`, `baileys` e `whatsmeow`.
- [x] Trava da janela de 24 horas desativada para provedores não oficiais em `Conversations::MessageWindowService`.
- [x] Envio de mensagens de sessão livre em `Whatsapp::SendOnWhatsappService`.
- [x] Provedor `Whatsapp::Providers::EvolutionService` implementado.
- [x] Provedor `Whatsapp::Providers::BaileysService` implementado.
- [x] Provedor `Whatsapp::Providers::WhatsmeowService` implementado.
- [x] Interface de cadastro de canal não oficial criada em `EvolutionWhatsapp.vue` e conectada a `Whatsapp.vue`.

### 3. Adaptações Mercado Brasileiro
- [x] Tratamento de duplicidade de 9º dígito integrado ao `ContactInboxWithContactBuilder` através de `expand_phone_number_candidates`.
- [x] Áudio gravado no navegador enviado com flag `ptt: true` e `audio/ogg; codecs=opus`.
- [x] Transcrição automática de áudio com OpenAI Whisper / Groq criada via `AudioTranscriptionService` e `AudioTranscriptionJob`.

### 4. Vendas e Automação
- [x] Serviço de geração de PIX Copia e Cola (`PixService`) com CRC16 implementado.
- [x] Visualizador de Funil de Vendas (Kanban CRM) criado em `KanbanView.vue`.
- [x] Rota `/accounts/:accountId/kanban` registrada e linkada no menu lateral (`Sidebar.vue`).
- [x] Aplicativo de integração nativo com Typebot configurado em `apps.yml`, `en.yml` e `pt_BR.yml`.
