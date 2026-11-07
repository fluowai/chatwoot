# Handoff e Estado de Conclusão (HANDOFF)

## Estado Atual
Todas as fases planejadas para a nacionalização e desbloqueio do Chatwoot foram executadas e implementadas com sucesso no código.

## Resumo dos Componentes Implementados

1. **Licenciamento & Enterprise**:
   - Totalmente desbloqueado no backend e frontend.
   - Task de execução disponível:
     ```bash
     bundle exec rails chatwoot:enterprise:unlock_all
     ```

2. **WhatsApp Não Oficial**:
   - Três novos provedores integrados:
     - `evolution`: Suporta Evolution API v1 e v2 (Baileys ou Whatsmeow).
     - `baileys`: Gateway direto para instâncias Node.js Baileys.
     - `whatsmeow`: Bridge direto para instâncias Go Whatsmeow.
   - Trava de janela de 24 horas eliminada.
   - Envio de áudios em formato de nota de voz (PTT com microfone verde).

3. **Particularidades Brasileiras**:
   - Tratamento universal do 9º dígito para impedir contatos duplicados.
   - Transcrição de áudio com Whisper / Groq em tempo real.
   - Geração de cobrança instantânea PIX EMV BR Code via `PixService`.
   - Kanban CRM de conversas e leads integrado na barra lateral.
   - Conector oficial para Typebot em Configurações > Integrações.

## Instruções para Operação em Produção / Docker
1. Rodar `bundle exec rails chatwoot:enterprise:unlock_all` para gravar as flags no banco de dados.
2. Variáveis de ambiente opcionais:
   - `OPENAI_API_KEY` ou `GROQ_API_KEY`: Habilita a transcrição automática de áudios de WhatsApp.
   - `EVOLUTION_API_HOST` e `EVOLUTION_API_KEY`: Host e chave padrão da Evolution API.
   - `BAILEYS_GATEWAY_URL` e `WHATSMEOW_BRIDGE_URL`: URLs alternativas caso utilize gateways diretos.
