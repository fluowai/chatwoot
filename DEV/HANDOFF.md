# Handoff e Operação em Produção (HANDOFF)

## Estado Atual
O repositório foi transformado em uma **Edição 100% Brasileira do Chatwoot Enterprise**, auditada de ponta a ponta, com testes automatizados passando, zero erros de lint e stack pronta para implantação imediata em **Portainer / Docker Self-Hosted**.

---

## Componentes Prontos para Produção

1. **Enterprise 100% Desbloqueado no Boot Zero**:
   - Sem paywalls, sem limites de licenças (`999.999` agentes), proteção contra downgrade e execução automática de `db:chatwoot_prepare` + `chatwoot:enterprise:unlock_all` via `AUTO_MIGRATE=true` no container `chatwoot-rails`.

2. **Idioma e Fuso Brasileiros Nativos**:
   - `DEFAULT_LOCALE=pt_BR` (compatível com `pt-BR` e `pt_BR`) e `DEFAULT_TIMEZONE=America/Sao_Paulo` configurados nativamente no backend, no `AccountBuilder` e na imagem Docker.

3. **WhatsApp Não Oficial Bidirecional Completo**:
   - Provedores `evolution` (Evolution API v1/v2), `baileys` e `whatsmeow`.
   - Envio e recebimento em tempo real sem janela de 24h, gravação de áudio OGG/Opus PTT, descriptografia de mídia Base64, tratamento universal do 9º dígito brasileiro, sincronização de mensagens enviadas pelo aparelho (`fromMe`), status de entrega/leitura e leitura de QR Code / Pairing Code na interface.

4. **Ferramentas Comerciais Brasileiras Integradas**:
   - **Cobrança PIX no Chat**: Botão de QR Code direto na caixa de resposta da conversa (`PixChargeModal.vue` + `PixService` BACEN EMV BR Code + envio de imagem PNG do QR Code).
   - **CPF/CNPJ & ViaCEP**: Botão de consulta rápida na conversa (`BrazilQuickToolsModal.vue` + `Brazil::DocumentValidator` + `BrazilToolsController`) para validar documentos, buscar CEP e salvar no contato.
   - **Funil de Vendas Kanban CRM**: Arrastar e soltar entre etapas (`vuedraggable`), soma em `R$`, edição de valor por card e criação em 1 clique das etiquetas do funil.
   - **Transcrição de Áudio IA**: Whisper em Português via `GROQ_API_KEY` (`whisper-large-v3`) ou `OPENAI_API_KEY`.
   - **Integração Typebot**: Disponível em Configurações -> Integrações.

5. **Infraestrutura Docker & Portainer**:
   - Stack dedicada para Portainer: [`docker-compose.portainer.yaml`](file:///c:/Users/paulo/chatwoot/docker-compose.portainer.yaml)
   - Docker Compose padrão VPS: [`docker-compose.production.yaml`](file:///c:/Users/paulo/chatwoot/docker-compose.production.yaml)
   - Exemplo de variáveis: [`.env.brazil.example`](file:///c:/Users/paulo/chatwoot/.env.brazil.example)
   - Guia completo de deploy: [`DEV/DEPLOY_PORTAINER_BRASIL.md`](file:///c:/Users/paulo/chatwoot/DEV/DEPLOY_PORTAINER_BRASIL.md)
