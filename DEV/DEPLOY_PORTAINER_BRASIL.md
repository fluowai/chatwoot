# Guia de Implantação Self-Hosted no Docker e Portainer (Edição Brasil)

Este guia documenta a implantação em produção da versão **Chatwoot Enterprise Brasil** (`ghcr.io/fluowai/chatwoot:latest`) em infraestrutura própria utilizando **Portainer** ou **Docker Compose**.

---

## 1. O que já sobe pronto automaticamente no Container

O entrypoint [`docker/entrypoints/rails.sh`](file:///c:/Users/paulo/chatwoot/docker/entrypoints/rails.sh) e o [`docker/Dockerfile`](file:///c:/Users/paulo/chatwoot/docker/Dockerfile) foram preparados especificamente para ambientes Linux / Portainer:

1. **Proteção contra CRLF**: Todos os scripts de inicialização são higienizados em tempo de build para `LF`.
2. **Edição Enterprise Nativa (`CW_EDITION=ee`)**: Sem limite de agentes (`999.999`), sem paywalls e sem rebaixamento pelo Hub externo.
3. **Auto-Migração e Auto-Desbloqueio (`AUTO_MIGRATE=true`)**: Na primeira subida (e em atualizações de versão), o container `chatwoot-rails` aguarda o PostgreSQL (`pgvector:pg16`), cria/migra as tabelas (`db:chatwoot_prepare`) e executa `chatwoot:enterprise:unlock_all` automaticamente — sem precisar abrir terminal SSH.
4. **Padrão Brasileiro Nativo**: Idioma `pt_BR` e fuso horário `America/Sao_Paulo` pré-configurados para o painel e para novas contas.
5. **Evolution API Integrada na Stack**: O arquivo [`docker-compose.portainer.yaml`](file:///c:/Users/paulo/chatwoot/docker-compose.portainer.yaml) já inclui o serviço `evolution-api` na mesma rede interna (`http://evolution-api:8080`), compartilhando PostgreSQL (schema isolado `evolution_api`) e Redis (DB `1`).

---

## 2. Passo a Passo no Portainer (Recomendado)

### Passo 1: Tornar o pacote GHCR acessível (se privado)
Caso o pacote `ghcr.io/fluowai/chatwoot:latest` esteja privado no GitHub:
- No Portainer, acesse **Registries -> Add registry -> Custom registry**:
  - **Name**: `GitHub Container Registry`
  - **Registry URL**: `ghcr.io`
  - **Authentication**: Ativado (usuário GitHub + Personal Access Token com escopo `read:packages`).
- *(Se você deixar o pacote como **Public** nas configurações do Package no GitHub, o Portainer baixa direto sem precisar cadastrar credencial).*

### Passo 2: Criar a Stack no Portainer
1. No menu lateral do Portainer, clique em **Stacks -> Add stack**.
2. Dê o nome `chatwoot-brasil`.
3. Em **Build method**, selecione **Web editor** e cole o conteúdo integral de [`docker-compose.portainer.yaml`](file:///c:/Users/paulo/chatwoot/docker-compose.portainer.yaml).
4. Role até **Environment variables** e adicione:

| Variável | Exemplo de Valor | Obrigatório? |
| :--- | :--- | :--- |
| `FRONTEND_URL` | `https://atendimento.suaempresa.com.br` | **Sim** |
| `SECRET_KEY_BASE` | String hexadecimal aleatória com 64+ caracteres | **Sim** |
| `POSTGRES_PASSWORD` | Senha forte alfanumérica (sem `@` ou `/`) | **Sim** |
| `REDIS_PASSWORD` | Senha forte alfanumérica | **Sim** |
| `EVOLUTION_API_KEY` | Chave secreta para autenticar na Evolution API | **Sim** |
| `GROQ_API_KEY` | `gsk_...` (para transcrição automática de áudios PT-BR) | Opcional |
| `PIX_DEFAULT_KEY` | CNPJ, CPF, E-mail, `+55...` ou Chave Aleatória | Opcional |
| `PIX_MERCHANT_NAME` | `MINHA EMPRESA LTDA` | Opcional |
| `PIX_MERCHANT_CITY` | `SAO PAULO` | Opcional |

5. Clique em **Deploy the stack**.

### Passo 3: Apontar seu Proxy Reverso (Nginx Proxy Manager / Traefik / Caddy)
- Aponte o domínio `atendimento.suaempresa.com.br` para a porta `3000` do servidor (com suporte a **WebSockets** habilitado para o ActionCable atualizar mensagens e transcrições em tempo real).
- Acesse `https://atendimento.suaempresa.com.br/installation/onboarding` no primeiro acesso para criar sua conta de Super Administrador!

---

## 3. Como Conectar o WhatsApp Não Oficial (QR Code)

1. No painel do Chatwoot, vá em **Configurações -> Caixas de Entrada -> Adicionar Caixa de Entrada -> WhatsApp**.
2. Escolha **WhatsApp Não Oficial (Evolution / Baileys / Whatsmeow)**.
3. Se estiver usando a stack Portainer integrada:
   - **Motor**: `Evolution API (v1 / v2 - Recomendado)`
   - **URL do Servidor**: `http://evolution-api:8080`
   - **Chave de Autenticação**: O valor definido em `EVOLUTION_API_KEY`
   - **Nome da Instância**: Ex: `comercial` (crie a instância na Evolution API ou aponte para uma existente)
4. Ao salvar, o Chatwoot configura automaticamente o Webhook de recebimento (`/webhooks/whatsapp/+55...`) com suporte a **áudio PTT (nota de voz OGG/Opus)**, **9º dígito brasileiro**, **mídias descriptografadas** e **leitura de QR Code** direto na tela!
