# Análise Comparativa: Baileys vs Whatsmeow para Chatwoot Brasil

## 1. Visão Geral
Atualmente, o Chatwoot suporta nativamente apenas provedores oficiais de WhatsApp (`whatsapp_cloud` - Cloud API da Meta e `default` - 360dialog).
Esses provedores possuem restrições severas para a realidade de PMEs no Brasil:
- Janela de atendimento de 24 horas forçada (`Conversations::MessageWindowService`).
- Cobrança por conversa (utility, marketing, service).
- Necessidade de aprovação de templates HSM junto à Meta.
- Risco de bloqueio do número caso a empresa não possua BM verificada.

Para o mercado brasileiro, a utilização de APIs não oficiais (baseadas na emulação da conexão WhatsApp Web multi-device) é a solução mais utilizada.

---

## 2. Comparativo Técnico: Baileys vs Whatsmeow

| Critério | Baileys (Node.js/TypeScript) | Whatsmeow (Go) |
| :--- | :--- | :--- |
| **Linguagem / Runtime** | Node.js / TypeScript | Go (Golang) / Binário compilado |
| **Adoção no Brasil** | **Dominante** (Evolution API v1/v2, CodeChat, Z-API, Z-Stack, WppConnect) | Crescente (utilizado em engines de alto volume e Evolution API v2 engine Go) |
| **Consumo de Memória (RAM)** | Médio/Alto (~150MB a 350MB por sessão ativa de WhatsApp) | **Extremamente Baixo** (~15MB a 50MB por sessão ativa) |
| **Consumo de CPU** | Moderado (V8 event loop) | **Baixo** (Goroutines de alta eficiência) |
| **Tratamento de Edge Cases BR (9º Dígito, LIDs)** | Amplamente testado e resolvido pela comunidade com helpers prontos | Exige implementação customizada dos regexes e normalização de JID/LID |
| **Áudios Gravados (PTT / Voice Notes)** | Suporte nativo completo com envio `audio/ogg; codecs=opus` e flag `ptt: true` | Requer integração com `ffmpeg` ou pipeline de transcodificação em Go |
| **Facilidade de Manutenção** | Alta (código aberto legível, ecossistema npm maduro) | Média/Alta (requer conhecimentos de Go para alterar protocolos internos) |
| **Resiliência a Desconexões** | Excelente com autenticação multi-file / redis | Excelente com SQLite / Postgres multi-session nativo |

---

## 3. Principais Desafios do WhatsApp Não Oficial no Brasil

1. **O Problema do 9º Dígito (DDI 55 + DDD + 9º Dígito)**:
   - No Brasil, os números de celular possuem 11 dígitos no formato `55 + DDD + 9XXXXXXXX`.
   - Contudo, contas antigas do WhatsApp foram registradas com 8 dígitos (`55 + DDD + XXXXXXXX`), enquanto novas têm 9 dígitos. Além disso, o WhatsApp introduziu o sistema de LIDs (Linked IDs).
   - Se a normalização falhar, o Chatwoot cria 2 contatos separados para o mesmo cliente, perde o histórico de conversas ou falha ao responder.
   - O Chatwoot já possui um normalizador base em `app/services/whatsapp/phone_normalizers/brazil_phone_normalizer.rb`. Ele precisa ser conectado aos canais não oficiais.

2. **Janela de 24 Horas**:
   - Em `app/services/conversations/message_window_service.rb`, o Chatwoot bloqueia o envio após 24 horas para o canal `Channel::Whatsapp`.
   - No provedor não oficial, essa trava DEVE ser desativada, permitindo resposta ilimitada.

3. **Áudio Gravado na Hora (PTT)**:
   - Clientes e atendentes brasileiros enviam áudios no WhatsApp. Se o áudio for enviado como documento ou arquivo simples (`audio/mpeg`, `.m4a`), o WhatsApp exibe como reprodutor de arquivo e não com a barra de onda verde do microfone.
   - O payload de envio precisa enviar `ptt: true` e formato `audio/ogg; codecs=opus`.

4. **Presença e Leitura (Digitando e Duplo Check Azul)**:
   - Enviar `composing` (digitando...) antes do envio da mensagem humaniza o atendimento e reduz a taxa de banimento.
   - Sincronização dos status `delivered` e `read`.

---

## 4. Modelos de Arquitetura de Integração com o Chatwoot

### Modelo 1: Sidecar Microservice Dedicado (Recomendado)
- Mantém um microsserviço leve (em Node.js/Baileys ou Go/Whatsmeow) rodando em conjunto no `docker-compose`.
- O Chatwoot ganha um novo provider em `Channel::Whatsapp`: `provider: "baileys"` ou `"whatsmeow"`.
- O Chatwoot exibe o QR Code e Pairing Code nativamente na tela de configuração da caixa de entrada (`WhatsappManualSetup.vue`).
- Vantagens:
  - Isolamento total de processos: falhas no WebSocket do WhatsApp nunca travam o Rails/Puma.
  - Atualização independente da biblioteca de WhatsApp quando o WhatsApp Web atualiza sua criptografia.

### Modelo 2: Gateway via Evolution API (Mais Rápido para Produção Imediata)
- A Evolution API é open-source, desenvolvida por brasileiros e suporta **AMBOS os motores**: Baileys e Whatsmeow!
- Possui integração nativa com o Chatwoot, enviando webhooks de mensagens, áudio PTT, mídias e lendo eventos.
- Podemos criar um painel interno no Chatwoot para gerenciar as instâncias da Evolution API, tornando a experiência 100% transparente para o usuário.

