# Contrato Ativo da Tarefa: Versão 100% Brasileira & Infraestrutura Docker/Portainer

## 1. Escopo Consolidado
- [x] Auditoria completa do repositório (Rails + Vue 3 + Enterprise + Docker).
- [x] Desbloqueio Enterprise perpétuo desde o primeiro boot (`config/installation_config.yml`, `ChatwootApp`, `ChatwootHub`, `usePolicy.js`, `rails.sh`).
- [x] Idioma padrão `pt_BR` (com normalização `pt-BR` -> `pt_BR`) e fuso padrão `America/Sao_Paulo` para novas contas e instalação.
- [x] Motor bidirecional completo para WhatsApp Não Oficial (`Evolution API v1/v2`, `Baileys`, `Whatsmeow`):
  - Envio de texto, mídia e nota de voz nativa OGG/Opus (`ptt: true`).
  - Recebimento em tempo real via webhook (`Whatsapp::IncomingMessageUnofficialService`) com descriptografia Base64, LID/JID, mensagens de eco do celular (`fromMe`), citações e recibos de entrega/leitura (`messages.update`).
  - Pareamento via QR Code e Pairing Code diretamente na interface do Chatwoot (`EvolutionWhatsapp.vue`).
- [x] Ferramentas Comerciais Brasileiras integradas na UI:
  - Cobrança Instantânea PIX no compositor de mensagens (`PixChargeModal.vue` + `PixService` BACEN EMV BR Code com CRC16-CCITT e envio de QR Code PNG).
  - Validador/Formatador de CPF e CNPJ (Mod-11) + Consulta de CEP via ViaCEP (`BrazilQuickToolsModal.vue` + `Brazil::DocumentValidator` + `BrazilToolsController`) com gravação direta no contato.
  - Funil de Vendas Kanban CRM com Drag-and-Drop (`vuedraggable`), soma automática em Reais (`R$`), edição inline de valor do negócio e criação automática das etiquetas do funil (`KanbanView.vue`).
  - Transcrição automática de áudios de WhatsApp em Português via Groq (`whisper-large-v3`) ou OpenAI (`whisper-1`).
  - Integração nativa Typebot.
- [x] Infraestrutura Self-Hosted Docker & Portainer 100% pronta (`docker-compose.portainer.yaml`, `docker-compose.production.yaml`, `.gitattributes` LF, `docker/entrypoints/rails.sh` com `AUTO_MIGRATE=true`).

## 2. Requisitos de Qualidade e Conformidade
- Zero erros e zero avisos no ESLint (incluindo `@intlify/vue-i18n/no-raw-text` e `vue/no-static-inline-styles`).
- Suíte de testes automatizados Vitest cobrindo regras de negócio brasileiras e componentes Vue.
- Build de produção frontend validado e arquivos YAML/JSON verificados.
- Nenhum commit/push automático sem solicitação explícita do Maestro.
