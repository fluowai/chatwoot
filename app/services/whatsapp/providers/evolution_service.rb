# frozen_string_literal: true

class Whatsapp::Providers::EvolutionService < Whatsapp::Providers::BaseService
  def send_message(phone_number, message)
    @message = message
    normalized_number = normalize_number(phone_number)

    if message.attachments.present?
      send_attachment_message(normalized_number, message)
    else
      send_text_message(normalized_number, message)
    end
  end

  def send_template(phone_number, _template_info, message)
    send_message(phone_number, message)
  end

  def sync_templates
    whatsapp_channel.mark_message_templates_updated
  end

  def validate_provider_config?
    api_host.present? && api_key.present? && instance_name.present?
  end

  def error_message(response)
    parsed = response.parsed_response
    if parsed.is_a?(Hash)
      parsed['message'] || parsed['error'] || response.body
    else
      response.body.to_s
    end
  end

  def connection_status
    url = "#{api_host}/instance/connectionState/#{ERB::Util.url_encode(instance_name)}"
    response = HTTParty.get(url, headers: headers, timeout: 10)
    return { state: 'error', error: error_message(response) } unless response.success?

    parsed = response.parsed_response.is_a?(Hash) ? response.parsed_response : {}
    state = parsed.dig('instance', 'state') || parsed['state'] || 'unknown'
    { state: state, instance: instance_name }
  rescue StandardError => e
    { state: 'unreachable', error: e.message }
  end

  def fetch_qr_code
    ensure_instance_exists
    url = "#{api_host}/instance/connect/#{ERB::Util.url_encode(instance_name)}"
    response = HTTParty.get(url, headers: headers, timeout: 15)
    return { error: error_message(response) } unless response.success?

    parsed = response.parsed_response.is_a?(Hash) ? response.parsed_response : {}
    {
      base64: parsed['base64'] || parsed.dig('qrcode', 'base64'),
      code: parsed['code'] || parsed.dig('qrcode', 'code'),
      pairing_code: parsed['pairingCode'] || parsed.dig('qrcode', 'pairingCode'),
      state: parsed.dig('instance', 'state') || parsed['state']
    }.compact
  rescue StandardError => e
    { error: e.message }
  end

  def ensure_instance_exists
    state_info = connection_status
    return true unless %w[error unreachable].include?(state_info[:state])

    base_url = ENV.fetch('INTERNAL_WEBHOOK_URL', ENV.fetch('FRONTEND_URL', 'http://localhost:3000')).chomp('/')
    webhook_url = "#{base_url}/webhooks/whatsapp/#{ERB::Util.url_encode(whatsapp_channel.phone_number)}"
    create_body = {
      instanceName: instance_name,
      qrcode: true,
      integration: 'WHATSAPP-BAILEYS',
      webhook: {
        url: webhook_url,
        byEvents: false,
        base64: true,
        events: %w[MESSAGES_UPSERT MESSAGES_UPDATE SEND_MESSAGE CONNECTION_UPDATE]
      }
    }
    HTTParty.post("#{api_host}/instance/create", headers: headers, body: create_body.to_json, timeout: 15)
  rescue StandardError => e
    Rails.logger.warn "[EVOLUTION] Auto-create instance skipped: #{e.message}"
    false
  end

  def configure_webhook(webhook_url)
    ensure_instance_exists
    url = "#{api_host}/webhook/set/#{ERB::Util.url_encode(instance_name)}"
    body = {
      webhook: {
        enabled: true,
        url: webhook_url,
        webhookByEvents: false,
        webhookBase64: true,
        events: %w[MESSAGES_UPSERT MESSAGES_UPDATE SEND_MESSAGE CONNECTION_UPDATE]
      }
    }
    response = HTTParty.post(url, headers: headers, body: body.to_json, timeout: 10)
    response.success?
  rescue StandardError => e
    Rails.logger.warn "[EVOLUTION] Auto webhook setup skipped: #{e.message}"
    false
  end

  def fetch_media_base64(raw_key)
    url = "#{api_host}/chat/getBase64FromMediaMessage/#{ERB::Util.url_encode(instance_name)}"
    body = { message: { key: raw_key }, convertToMp4: false }
    response = HTTParty.post(url, headers: headers, body: body.to_json, timeout: 25)
    return nil unless response.success?

    parsed = response.parsed_response
    parsed.is_a?(Hash) ? parsed['base64'] : nil
  rescue StandardError => e
    Rails.logger.warn "[EVOLUTION] getBase64FromMediaMessage failed: #{e.message}"
    nil
  end

  private

  def api_host
    host = whatsapp_channel.provider_config['api_host'].presence ||
           ENV['EVOLUTION_API_HOST'].presence ||
           GlobalConfigService.load('EVOLUTION_API_HOST', nil).presence
    host&.chomp('/')
  end

  def api_key
    whatsapp_channel.provider_config['api_key'].presence ||
      ENV['EVOLUTION_API_KEY'].presence ||
      GlobalConfigService.load('EVOLUTION_API_KEY', nil).presence
  end

  def instance_name
    whatsapp_channel.provider_config['instance_name'].presence || whatsapp_channel.phone_number.to_s.delete('+')
  end

  def normalize_number(number)
    clean = number.to_s.gsub(/\D/, '')
    normalizer = Whatsapp::PhoneNormalizers::BrazilPhoneNormalizer.new
    normalizer.handles_country?(clean) ? normalizer.normalize(clean) : clean
  end

  def headers
    {
      'Content-Type' => 'application/json',
      'apikey' => api_key.to_s
    }
  end

  def send_text_message(phone_number, message)
    url = "#{api_host}/message/sendText/#{ERB::Util.url_encode(instance_name)}"
    body = {
      number: phone_number,
      text: message.outgoing_content.presence || message.content.to_s,
      delay: 1200
    }

    response = HTTParty.post(url, headers: headers, body: body.to_json, timeout: 20)
    process_evolution_response(response, message)
  end

  def send_attachment_message(phone_number, message)
    attachment = message.attachments.first
    return if attachment.blank?

    file_url = attachment.download_url

    if attachment.audio?
      send_audio_voice_note(phone_number, file_url, message)
    else
      send_media_file(phone_number, file_url, attachment, message)
    end
  end

  def send_audio_voice_note(phone_number, audio_url, message)
    url = "#{api_host}/message/sendWhatsAppAudio/#{ERB::Util.url_encode(instance_name)}"
    body = {
      number: phone_number,
      audio: audio_url,
      delay: 1500,
      encoding: true
    }

    response = HTTParty.post(url, headers: headers, body: body.to_json, timeout: 30)
    process_evolution_response(response, message)
  end

  def send_media_file(phone_number, file_url, attachment, message)
    url = "#{api_host}/message/sendMedia/#{ERB::Util.url_encode(instance_name)}"
    body = {
      number: phone_number,
      media: file_url,
      mediatype: media_type_for(attachment),
      caption: message.outgoing_content.presence || message.content.to_s,
      fileName: attachment.file.filename.to_s
    }

    response = HTTParty.post(url, headers: headers, body: body.to_json, timeout: 30)
    process_evolution_response(response, message)
  end

  def media_type_for(attachment)
    if attachment.image?
      'image'
    elsif attachment.video?
      'video'
    else
      'document'
    end
  end

  def process_evolution_response(response, message)
    if response.success?
      parsed = response.parsed_response.is_a?(Hash) ? response.parsed_response : {}
      msg_id = parsed.dig('key', 'id') || parsed['messageId'] || parsed['id']
      message.update!(source_id: msg_id) if msg_id.present?
      msg_id
    else
      handle_error(response, message)
      nil
    end
  end
end
