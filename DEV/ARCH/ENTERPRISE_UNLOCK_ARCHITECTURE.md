# Arquitetura de Desbloqueio Enterprise / Funções Pagas

## 1. Como o Chatwoot gerencia funcionalidades pagas (Enterprise)

O Chatwoot possui uma estrutura híbrida entre o código Open Source (`app/`) e o Enterprise (`enterprise/`):

1. **Detecção da Edição**:
   - `ChatwootApp.enterprise?` verifica se o diretório `enterprise/` existe e se `ENV['DISABLE_ENTERPRISE']` não é falso.
   - Como a pasta `enterprise/` já está presente neste repositório, `ChatwootApp.enterprise?` já avalia como `true`.

2. **Gatilhos de Licença e Hub**:
   - `ChatwootHub.pricing_plan` consulta `InstallationConfig.find_by(name: 'INSTALLATION_PRICING_PLAN')&.value`.
   - Se for `'community'`, os componentes do frontend (`usePolicy.js`, `SuperAdmin::AccountFeaturesHelper`) tratam as funções como bloqueadas (`premium_locked = true`).
   - A rotina de background `Internal::CheckNewVersionsJob` consulta periodicamente `https://hub.2.chatwoot.com/ping`. Se a instância não tiver plano pago ativo registrado no Hub da Chatwoot, ela atualiza `INSTALLATION_PRICING_PLAN` para `'community'`, disparando o serviço `Internal::ReconcilePlanConfigService`, que remove as flags premium dos accounts e reverte a marca para Chatwoot.

3. **Bitset de Feature Flags em Contas**:
   - As flags de cada conta são armazenadas nas colunas `feature_flags` e `feature_flags_ext_1` (utilizando a gem `flag_shih_tzu`).
   - O arquivo `config/features.yml` lista quais flags vêm ativadas (`enabled: true`) ou desativadas por padrão (`enabled: false`), incluindo as que têm `premium: true`.
   - Ao criar uma nova conta, o método `Featurable#enable_default_features` lê `ACCOUNT_LEVEL_FEATURE_DEFAULTS` da tabela `installation_configs`.

4. **Limite de Agentes**:
   - Em `enterprise/app/models/enterprise/concerns/user.rb`, existe o callback:
     ```ruby
     def ensure_installation_pricing_plan_quantity
       return unless ChatwootHub.pricing_plan == 'premium'
       errors.add(:base, 'User limit reached...') if User.count >= ChatwootHub.pricing_plan_quantity
     end
     ```
   - Quando o plano é `'enterprise'`, essa restrição de quantidade NÃO é disparada!

## 2. Estratégia de Desbloqueio Permanente

Para desbloquear 100% das funções de forma definitiva e segura contra regressões ou chamadas externas:

1. **Fixação do Plano Enterprise no Hub Local**:
   - No arquivo `lib/chatwoot_hub.rb`:
     - Retornar `'enterprise'` em `self.pricing_plan`.
     - Retornar `999_999` em `self.pricing_plan_quantity`.
     - Interceptar `self.sync_with_hub` para nunca sobrescrever o plano local para `'community'`.
   - No `enterprise/app/jobs/enterprise/internal/check_new_versions_job.rb`:
     - Impedir que `update_plan_info` altere o plano ou status de assinatura para algo inferior a enterprise / ativo.
   - No `enterprise/app/services/internal/reconcile_plan_config_service.rb`:
     - Tornar `perform` no-op caso seja disparado indevidamente.

2. **Liberação das Flags por Padrão**:
   - Ajustar `config/features.yml` para que recursos essenciais (audit_logs, sla, custom_roles, captain, copilot_workflows, disable_branding, custom_branding, agent_capacity, conversation_required_attributes, conversation_monitors, campaign_analytics, voice_calls, auto_translate) venham habilitados por padrão para novas contas.
   - Criar uma tarefa Rake ou script de migração para ativar todos os bits de feature flags nas contas já existentes:
     ```ruby
     Account.find_each do |account|
       account.enable_features!(*Featurable::FEATURE_LIST.pluck('name'))
     end
     ```

3. **Frontend & Paywalls**:
   - No composable `app/javascript/dashboard/composables/usePolicy.js`:
     - Garantir que `hasPremiumEnterprise` sempre avalie como `true`.
     - Garantir que `shouldShowPaywall` sempre retorne `false`.
   - Configurações globais (`InstallationConfig`):
     - `INSTALLATION_PRICING_PLAN` = `'enterprise'`
     - `INSTALLATION_SUBSCRIPTION_STATUS` = `'active'`
     - `DEPLOYMENT_ENV` = `'self-hosted'`

