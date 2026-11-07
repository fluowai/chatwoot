module Enterprise::ChatwootHub
  ENTERPRISE_BASE_URL = 'https://hub.2.chatwoot.com'.freeze

  def subscription_status
    status = InstallationConfig.find_by(name: 'INSTALLATION_SUBSCRIPTION_STATUS')&.value
    status.presence || 'active'
  end

  def base_url
    return ENV.fetch('CHATWOOT_HUB_URL', ENTERPRISE_BASE_URL) if Rails.env.development?

    ENTERPRISE_BASE_URL
  end
end
