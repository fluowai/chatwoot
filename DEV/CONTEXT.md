# Contexto do Projeto: Chatwoot Brasil

## 1. Visão Geral
Adaptar o Chatwoot Open Source para o mercado brasileiro, transformando-o em uma plataforma de atendimento multicanal e vendas de alta performance, sem travas comerciais da versão Cloud/Enterprise oficial e com integração de WhatsApp Não Oficial (Baileys / Whatsmeow).

## 2. Objetivos Principais
1. **Desbloqueio Total de Funcionalidades Enterprise / Pagas**:
   - Ativação permanente de SLA, Auditoria (Audit Logs), Funções Customizadas (Custom Roles), Captain AI / Copilot, Desativação de Marca (Whitelabel), Regras de Capacidade (Agent Capacity), Atributos Obrigatórios de Conversa, Monitoria de Conversas e Campanhas Avançadas.
   - Remoção de qualquer bloqueio de quantidade de agentes (`INSTALLATION_PRICING_PLAN_QUANTITY`).
   - Prevenção contra downgrade automático via sincronização com `hub.2.chatwoot.com`.

2. **WhatsApp Não Oficial (Baileys vs Whatsmeow)**:
   - Superar o custo e as travas da API Oficial da Meta (Cloud API):
     - Eliminar a regra da janela de 24 horas (`Conversations::MessageWindowService`).
     - Permitir envio de mensagens de sessão a qualquer momento.
     - Suporte a conexão via QR Code e Código de Pareamento (Pairing Code).
     - Áudio em formato de nota de voz (PTT - gravando áudio) em vez de anexo de arquivo.
     - Suporte a digitação ("digitando..."), visualização (duplo check azul), reações e stickers.

3. **Adaptações e Correções Específicas para o Brasil**:
   - Tratamento do 9º dígito brasileiro (DDD + 9 dígitos vs 8 dígitos legados no WhatsApp).
   - Suporte a pagamentos PIX (geração de QR Code e Copia e Cola direto no chat).
   - Integração com Typebot (fluxos conversacionais visuais) e n8n.
   - Visualização em Kanban / Funil de Vendas (CRM).
   - Transcrição de áudios longos de WhatsApp via IA (Whisper / Groq).
   - Localização refinada em Português do Brasil (pt-BR).

