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

### 5. Fase 5: GitHub Actions Cloud Docker Build
- Configurado workflow `.github/workflows/build-fluow-docker.yml` para compilação automatizada na nuvem do GitHub Actions.
- O GitHub constrói a imagem Docker (com suporte a Buildx e cache de camadas) e publica no GitHub Container Registry (`ghcr.io/fluowai/chatwoot:latest`).
- Desativados gatilhos com push das actions antigas da upstream (`publish_ee_docker.yml` e `publish_foss_docker.yml`), mantendo apenas acionamento manual.
- Repositório local atualizado e pronto para sincronização com `https://github.com/fluowai/chatwoot.git`.

## [2026-11-17] Nacionalização 100% Brasil, Correções Críticas de Produção, Testes e Stack Portainer

### 1. Correções Críticas de Bugs e Lacunas Encontradas na Auditoria
- **Proteção contra CRLF em Containers Linux (`.gitattributes` + `docker/Dockerfile`)**:
  - Adicionado `.gitattributes` forçando `eol=lf` e higienização `sed -i 's/\r$//'` em `docker/Dockerfile` para evitar falha `exec docker/entrypoints/rails.sh: no such file or directory` no Portainer.
- **Desbloqueio Enterprise desde o Boot Zero (`config/installation_config.yml` + `lib/chatwoot_app.rb`)**:
  - Alterado `INSTALLATION_PRICING_PLAN` padrão de `'community'` para `'enterprise'` e `INSTALLATION_PRICING_PLAN_QUANTITY` para `999999`, além de `DISABLE_META_INBOX_CREATION: false` e `DISABLE_META_MESSAGE_SENDING: false`.
  - Adicionadas chaves editáveis no Super Admin para `GROQ_API_KEY`, `EVOLUTION_API_HOST`, `EVOLUTION_API_KEY`, `PIX_DEFAULT_KEY`, `PIX_MERCHANT_NAME` e `PIX_MERCHANT_CITY`.
- **Recebimento Bidirecional de Webhooks WhatsApp Não Oficial**:
  - Criados `Whatsapp::UnofficialChannelFinderService` e `Whatsapp::IncomingMessageUnofficialService`, conectados a `Webhooks::WhatsappController` e `Webhooks::WhatsappEventsJob`.
  - Suporte completo a Evolution API (v1/v2), Baileys e Whatsmeow: texto, áudio, imagem, vídeo, documento, localização, descriptografia Base64, resolução de `@lid`, sincronização de mensagens enviadas pelo celular (`fromMe`), resposta citada (`in_reply_to`) e atualização de status (`delivered`/`read`/`failed`).
  - Protegido `Channel::Whatsapp#teardown_webhooks` (`unless: :unofficial_provider?`) e adicionada configuração automática de webhook na criação do canal.
- ** Correção de Áudio OGG/Opus no Navegador (`ReplyBox.vue`)**:
  - Habilitado `AUDIO_FORMATS.OGG` para `evolution`, `baileys` e `whatsmeow` (antes gravava em MP3), garantindo nota de voz PTT nativa no iOS e Android.
- **Correção Crítica do Payload PIX BACEN (`PixService` + `brazilHelpers.js`)**:
  - Corrigida sanitização do campo `txid` que removia os asteriscos de `'***'` (gerando `62040500` rejeitado pelos bancos brasileiros). Agora preserva `'***'` ou sanitiza alfanumérico sem espaços conforme especificação oficial EMV BR Code do Banco Central.

### 2. Novas Funcionalidades Brasileiras de Ponta a Ponta
- **Modal de Cobrança PIX no Chat (`PixChargeModal.vue` + `ReplyBottomPanel.vue` + `ReplyBox.vue`)**:
  - Geração instantânea de QR Code oficial e código PIX Copia e Cola direto na barra de resposta da conversa, com opção de enviar mensagem formatada + imagem PNG do QR Code em 1 clique.
- **Utilitários Brasil: CPF/CNPJ e ViaCEP (`BrazilQuickToolsModal.vue` + `Brazil::DocumentValidator` + `Api::V1::Accounts::BrazilToolsController`)**:
  - Validação real de dígitos verificadores Mod-11 de CPF e CNPJ, busca de endereço por CEP via ViaCEP, inserção rápida na conversa e gravação direta nos `custom_attributes` do contato.
- **Kanban CRM Drag-and-Drop (`KanbanView.vue`)**:
  - Reescrito em Vue 3 `<script setup>` com `vuedraggable`, filtro por canal e busca textual, valor do negócio em Reais (`R$`) editável no card, soma financeira por coluna e criação automática das etiquetas do funil.
- **Conexão WhatsApp com QR Code ao Vivo (`EvolutionWhatsapp.vue`)**:
  - Reescrito em `<script setup>` com seleção de motor (`evolution`, `baileys`, `whatsmeow`), normalização automática do 9º dígito, cópia da URL de Webhook e leitura de QR Code / Pairing Code na própria tela.
- **Internacionalização Completa (`pt_BR/brazil.json` e `en/brazil.json`)**:
  - Idioma padrão `pt_BR` e fuso `America/Sao_Paulo` em `SwitchLocale` e `AccountBuilder`. Zero textos hardcoded nos templates Vue.

### 3. Infraestrutura Docker & Portainer Self-Hosted
- Criado `docker-compose.portainer.yaml` (stack completa com PostgreSQL `pgvector:pg16`, Redis 7, Chatwoot Rails com `AUTO_MIGRATE=true`, Sidekiq e Evolution API integrada sem dependência de arquivo `.env` em disco).
- Atualizados `docker/entrypoints/rails.sh`, `docker-compose.production.yaml`, `.env.brazil.example` e guia `DEV/DEPLOY_PORTAINER_BRASIL.md`.
