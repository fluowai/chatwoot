# Registro de Trabalho (WORKLOG)

## [2026-11-07] Execução Integral de Todas as Fases: Chatwoot Brasil & Desbloqueio Enterprise

### 1. Fase 1: Desbloqueio Enterprise Perpétuo
- **`lib/chatwoot_hub.rb`**:
  - Ajustado `self.pricing_plan` para garantir retorno do plano `'enterprise'` sem rebaixar para `'community'`.
  - Ajustado `self.pricing_plan_quantity` para `999_999`.
- **`enterprise/lib/enterprise/chatwoot_hub.rb`**:
  - `subscription_status` definido para retornar `'active'`.
- **`enterprise/app/jobs/enterprise/internal/check_new_versions_job.rb`**:
  - Protegido contra downgrade periódico e cancelamento de assinatura originados do Hub oficial da Chatwoot.
- **`enterprise/app/views/fields/account_features_field/_form.html.erb`**:
  - Removido travamento dos checkboxes de recursos premium no Super Admin (`premium_locked = false`).
- **`app/javascript/dashboard/composables/usePolicy.js`**:
  - `hasPremiumEnterprise` definido como `true`.
  - `shouldShowPaywall` ajustado para retornar `false` (eliminação global de paywalls e banners de upgrade).
- **`config/features.yml`**:
  - Atualizadas todas as flags de recursos Enterprise/Premium para `enabled: true` por padrão (`audit_logs`, `sla`, `custom_roles`, `captain_integration`, `channel_voice`, `disable_branding`, `advanced_search`, `saml`, `conversation_required_attributes`, `conversation_monitors`, `campaign_analytics`, etc.).
- **`lib/tasks/enterprise_unlock.rake`**:
  - Criada task `chatwoot:enterprise:unlock_all` para ativar todos os bits de feature flags em 100% das contas do banco e configurar as chaves de `InstallationConfig`.

### 2. Fase 2: WhatsApp Não Oficial (Baileys / Whatsmeow / Evolution)
- **`app/models/channel/whatsapp.rb`**:
  - Adicionados os provedores `baileys`, `whatsmeow` e `evolution` ao array `PROVIDERS`.
  - Adicionado helper `unofficial_provider?`.
  - Mapeamento dinâmico em `provider_service` para instanciar o serviço correto de envio.
  - Bypass de validação de credenciais oficiais da Meta para provedores não oficiais.
- **`app/services/conversations/message_window_service.rb`**:
  - Desativada a restrição da janela de 24 horas (`MESSAGING_WINDOW_24_HOURS`) para canais não oficiais e canais com flag `ignore_messaging_window`.
- **`app/services/whatsapp/send_on_whatsapp_service.rb`**:
  - Permitido envio direto de mensagens de sessão a qualquer tempo quando `channel.unofficial_provider?` for verdadeiro.
- **Provedores Criados**:
  - `app/services/whatsapp/providers/evolution_service.rb`: Integração com Evolution API (v1 e v2) com suporte a Baileys e Whatsmeow.
  - `app/services/whatsapp/providers/baileys_service.rb`: Gateway direto Baileys com áudio PTT e mídias.
  - `app/services/whatsapp/providers/whatsmeow_service.rb`: Bridge Go Whatsmeow com alta densidade de conexões.
- **Interface Frontend**:
  - Criado componente `EvolutionWhatsapp.vue` e integrado a `Whatsapp.vue` para criação de caixas de entrada não oficiais diretamente pela UI do Chatwoot.

### 3. Fase 3: Adaptações Críticas para o Mercado Brasileiro
- **Normalização Universal do 9º Dígito (`ContactInboxWithContactBuilder`)**:
  - Aprimorado `find_contact_by_phone_numbers` com `expand_phone_number_candidates`, resolvendo automaticamente números brasileiros com e sem 9º dígito (`+55119...` e `+5511...`), impedindo duplicação de contatos e conversas fragmentadas.
- **Áudios como Nota de Voz (PTT)**:
  - Implementada transmissão com flag `ptt: true` e mimetype `audio/ogg; codecs=opus`, fazendo com que áudios do navegador sejam ouvidos no WhatsApp como notas de voz nativas.
- **Transcrição de Áudios via Whisper / Groq**:
  - Criados `AudioTranscriptionService` e `AudioTranscriptionJob`.
  - Configurado gancho `after_create_commit :enqueue_audio_transcription_job, if: :audio?` em `Attachment`.
  - Áudios recebidos ou enviados são transcritos em segundo plano e renderizados em tempo real via ActionCable na bolha de áudio.

### 4. Fase 4: Recursos Avançados para Vendas e Automação
- **Gerador de PIX Copia e Cola e QR Code (`PixService`)**:
  - Criado serviço nativo em Ruby no padrão oficial do Banco Central (EMV BR Code) com cálculo de CRC16 para cobranças instantâneas em chat.
- **Funil de Vendas (Kanban CRM)**:
  - Criado componente `KanbanView.vue` com colunas dinâmicas de etapas de vendas (Lead, Qualificação, Negociação, Fechado, Perdido).
  - Registrada rota `/accounts/:accountId/kanban` em `conversation.routes.js`.
  - Adicionado atalho direto "Kanban CRM" no menu lateral do Chatwoot (`Sidebar.vue`).
- **Integração com Typebot**:
  - Adicionado aplicativo nativo Typebot em `config/integration/apps.yml`.
  - Adicionadas traduções completas em `en.yml` e `pt_BR.yml`.
