# frozen_string_literal: true

namespace :chatwoot do
  namespace :enterprise do
    desc 'Desbloqueia todas as funções Enterprise, remove limites de licença e ativa flags em todas as contas'
    task unlock_all: :environment do
      puts "\n======================================================="
      puts '🚀 CHATWOOT ENTERPRISE UNLOCK - BRASIL'
      puts "=======================================================\n"

      configs = {
        'INSTALLATION_PRICING_PLAN' => 'enterprise',
        'INSTALLATION_PRICING_PLAN_QUANTITY' => '999999',
        'INSTALLATION_SUBSCRIPTION_STATUS' => 'active',
        'DEPLOYMENT_ENV' => 'self-hosted'
      }

      configs.each do |key, value|
        config = InstallationConfig.find_or_initialize_by(name: key)
        config.value = value
        config.locked = true
        config.save!
        puts "   ✅ Configuração definida: #{key} = #{value}"
      end

      feature_list = YAML.safe_load(Rails.root.join('config/features.yml').read)
      all_feature_names = feature_list.pluck('name')
      default_features = feature_list.map do |f|
        f.merge('enabled' => true)
      end

      defaults_config = InstallationConfig.find_or_initialize_by(name: 'ACCOUNT_LEVEL_FEATURE_DEFAULTS')
      defaults_config.value = default_features
      defaults_config.locked = true
      defaults_config.save!
      puts '   ✅ Padrões de features para novas contas atualizados com sucesso.'

      accounts_count = Account.count
      puts "\n   🔄 Atualizando #{accounts_count} conta(s) existente(s)..."

      Account.find_each do |account|
        account.enable_features!(*all_feature_names)
        print '.'
      end
      puts "\n   ✅ Todas as contas foram atualizadas com 100% dos recursos Enterprise ativados!"

      GlobalConfig.clear_cache
      puts "   ✅ Cache do GlobalConfig limpo com sucesso.\n"
      puts "🎉 Desbloqueio concluído com sucesso! Chatwoot Enterprise 100% ativo.\n\n"
    end
  end
end

